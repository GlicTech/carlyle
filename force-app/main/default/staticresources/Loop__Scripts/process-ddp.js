/*
    Consumers of this script must attach Custom Labels to the window object
    The method for accomplishing this will vary depending on if the consumer is VisualForce, Aura, or LWC
    Examples can be found in processDDP.component (VisualForce) and in ProcessDdpController.js (Aura)
    The list of required Custom Labels:
        window.queuedLabel
        window.sendingRequestLabel
        window.processingRequestLabel
        window.timeoutHasExpiredLabel
        window.includeThisErrorIdLabel
        window.successYourRequestHasBeenCompletedLabel
        window.anUnexpectedErrorHasOccurredLabel
        window.authorizeAndSendtoDocuSignLabel
*/
(function($) {
    if (window.Drawloop && window.Drawloop.ddpRunner) {
		return;
	}

    function setTimeoutLightning(func, delay) {
        if (typeof $A !== 'undefined') {
            setTimeout($A.getCallback(func), delay);
        } else {
            setTimeout(func, delay);
        }
    }

    function DdpRunner() {
        var runner = this;
        var checkInterval = 250;
        var maxJobs = 1;
        var stylesLoaded = {};

        this.jobs = {
            queued: [],
            running: [],
            complete: []
        };

        this.loadCSS = function(url, callback) {
            if (url in stylesLoaded) {
                callback();
                return;
            }

            var link = document.createElement('link');
            link.type = 'text/css';
            link.rel = 'stylesheet';
            link.media = 'screen,print';
            link.href = url;
            link.onload = function() {
                stylesLoaded[url] = true;
                callback();
            };

            document.getElementsByTagName('head')[0].appendChild(link);
        };

        this.waitForCSS = function(styleUrl, callback) {
            if (styleUrl in stylesLoaded) {
                callback();
            } else {
                setTimeoutLightning(function() {
                    runner.waitForCSS(styleUrl, callback);
                }, checkInterval);
            }
        };

        function run(component, data, styleUrl) {
            runner.waitForCSS(styleUrl, function() {
                if (!data.id) {
                    throw 'No DocGen Package specified';
                }

                component.log('Running DocGen Package: ' + data.id);
				var isRdlc = component.options.isRdlc;
				var isLightning = component.options.isLightning;
				var isOAuthEnabled = component.options.isOAuthEnabled;

                var startTime = new Date();

                function getStatus(jobId, showProgress) {
                    if (typeof showProgress === 'undefined') showProgress = true;

                    component.client.getStatus(jobId, function(response) {
                        if (component.client.handleError(response)) return;

                        if ((new Date() - startTime) > component.options.timeout) {
                            component.client.options.onErrorCallback(
                              component.client.withDefaultArgs({ errorId: null, message: window.timeoutHasExpiredLabel + jobId }));

                            component.client.complete = true;
                            return;
                        }

                        // If we are still running, invoke the onprogress callback and
                        // queue another callback to check status
                        if (component.client.checkJobStatus(response, 'Running')) {
                            if (showProgress) {
                                component.client.options.onProgressCallback(
                                    component.client.withDefaultArgs({ percent: response.job.percentComplete, message: response.job.message }));
                            }
                            setTimeoutLightning(function() {
                                getStatus(jobId, showProgress);
                            }, component.options.pollPause);
                        } else {
                            component.log('Getting files for job: ' + jobId);

                            component.client.getResult(jobId, function(response) {
                                component.log('Retrieved files: ' + JSON.stringify(response));
                                if (component.client.handleError(response)) return;

                                // We don't support Pause-to-Edit in this UI yet, so just automatically continue
                                // if we detect that we are paused for editing documents
                                if (component.client.checkIsPauseToEditResponse(response)) {
                                    component.client.continueRun(jobId, function(response) {
                                        component.log('Continue response: ' + JSON.stringify(response));
                                        if (component.client.handleError(response)) return;

                                        setTimeoutLightning(function() {
                                            getStatus(jobId);
                                        }, component.options.pollPause);
                                    });
                                } else {
                                    // For the purposes of DocGen Package queueing, consider a DocGen Package to be complete when we present
                                    // the user with the preview step, rather than once the continue step has been called (where applicable)
                                    component.client.complete = true;

                                    // Present user with Preview panel
                                    var $preview = component.$container.find('.panel-preview').html('');

                                    component.UI.showPanel('.panel-preview');

                                    if (!(component.client.checkJobStatus(response, 'Complete') && component.options.isAutoRun)) {
                                        var $fr = $('<div class="list-group section-files" />').appendTo($preview);
                                        var runDdpComponent = component.options.componentId ? $A.getComponent(component.options.componentId) : "";
                                        var files = [];

                                        for (var i = 0; i < response.job.files.length; i++) {
                                            var f = response.job.files[i];

                                            var file = {};
                                            if (isRdlc) {
                                                file.link = component.client.getFileUrl(f.relativeFileUrl, false);
                                                file.name = f.fileName;
                                                file.fileType = f.fileName.substr(f.fileName.lastIndexOf('.') + 1);
                                                files.push(file);
                                            } else {
                                                // In the future, when the error response uses a message instead
                                                // of a string, we can update this such that it redirects an iframe
                                                // in Chrome and Firefox instead of opening in a new tab
                                                var $a = $('<a class="list-group-item" target="_blank"/>')
                                                    .css('cursor', 'pointer')
                                                    .text(f.fileName)
                                                    .attr(
                                                        'href',
                                                        component.client.getFileUrl(f.relativeFileUrl, true)
                                                    );

                                                $fr.append($a);
                                            }
                                        }

                                        if (isRdlc) {
                                            runDdpComponent.set("v.downloadLinks", files);

                                            if (response.job && response.job.data && response.job.data.returnUri) {
                                                runDdpComponent.set('v.returnUri', response.job.data.returnUri);
                                            }
                                        }
                                    }

                                    if (component.client.checkJobStatus(response, 'Paused')) {
										if (isRdlc) {
                                            var runDdpComponent = $A.getComponent(component.options.componentId);
                                            var continueButton  = runDdpComponent.find('previewFiles').find('continueButton').getElement();
                                            continueButton.innerHTML = '';

                                            if(response.job.needsDSICAuth) {
                                                var processDdpComponent = runDdpComponent.find('processDdp');
                                                var docuSignOAuthApiUrl = processDdpComponent.get('v.docuSignOAuthApiUrl');

                                                $('<div class="section-buttons list-group" />')
                                                    .appendTo(continueButton)
                                                    .append(
                                                        $('<button type="button" class="slds-button slds-button--brand slds-m-top--x-small"></button>')
                                                            .text(window.authorizeAndSendtoDocuSignLabel)
                                                            .click(function() {
                                                                window.Drawloop.eventListener.addEventListener( 'docuSign',function(event) {
                                                                        var payload = JSON.parse(event.data.payload);
                                                                        if (payload.isSuccess) {
                                                                            $(this).addClass('disabled');

                                                                            var continueShowProgress = false;

                                                                            for (var i = 0; i < response.job.files.length; i++) {
                                                                                if (response.job.files[i].replaceable) {
                                                                                    continueShowProgress = true;
                                                                                    break;
                                                                                }
                                                                            }

                                                                            component.client.continueRun(jobId, function(response) {
                                                                                if (component.client.handleError(response)) return;

                                                                                if (continueShowProgress) {
                                                                                    component.UI.showPanel('.panel-progress');
                                                                                }

                                                                                setTimeoutLightning(function() {
                                                                                    getStatus(jobId, continueShowProgress);
                                                                                }, component.options.pollPause);
                                                                            });
                                                                        } else {
                                                                            var previewFiles = runDdpComponent.find('previewFiles');
                                                                            previewFiles.hideLoading();
                                                                        }
                                                                });

                                                                var docuSignOAuthWindowOpened = window.open(
                                                                    docuSignOAuthApiUrl.replace("consent=Admin", "consent=Individual"),
                                                                    'Authorize DocuSign',
                                                                    'height=750,width=750,location=0,status=0,titlebar=0'
                                                                );

                                                                function checkWindow() {
                                                                    if (docuSignOAuthWindowOpened.closed) {
                                                                        var data = {
                                                                            message: 'docuSign',
                                                                            payload: JSON.stringify({isSuccess: false, errorDescription: 'User closed the window'})
                                                                        }
                                                                        window.postMessage(data, window.location.href);
                                                                    } else {
                                                                        setTimeout(checkWindow, 100);
                                                                    }
                                                                }

                                                                checkWindow();
                                                            })
                                                    );
                                            } else {
                                                continueButton.innerHTML = '';
                                                $('<div class="section-buttons list-group" />')
                                                    .appendTo(continueButton)
                                                    .append(
                                                        $('<button type="button" class="slds-button slds-button--brand slds-m-top--x-small"></button>')
                                                            .text(component.client.options.previewButtonText)
                                                            .click(function() {
                                                                $(this).addClass('disabled');

                                                                var continueShowProgress = false;

                                                                for (var i = 0; i < response.job.files.length; i++) {
                                                                    if (response.job.files[i].replaceable) {
                                                                        continueShowProgress = true;
                                                                        break;
                                                                    }
                                                                }

                                                                component.client.continueRun(jobId, function(response) {
                                                                    component.log('Continue response: ' + JSON.stringify(response));
                                                                    if (component.client.handleError(response)) return;

                                                                    if (continueShowProgress) {
                                                                        component.UI.showPanel('.panel-progress');
                                                                    }

                                                                    setTimeoutLightning(function() {
                                                                        getStatus(jobId, continueShowProgress);
                                                                    }, component.options.pollPause);
                                                                });
                                                            })
                                                    );
                                            }
                                            var continueButtonContainer = $A.getComponent(component.client.options.componentId).find('continueButtonContainer');
                                            $A.util.removeClass(continueButtonContainer, 'hidden');
										} else {
											$('<div class="section-buttons list-group" />')
												.appendTo($preview)
												.append(
													$('<button type="button" class="btn btn-primary btn-continue"></button>')
														.text(component.client.options.previewButtonText)
														.click(function() {
															$(this).addClass('disabled');

															var continueShowProgress = false;

															for (var i = 0; i < response.job.files.length; i++) {
																if (response.job.files[i].replaceable) {
																	continueShowProgress = true;
																	break;
																}
															}

															component.client.continueRun(jobId, function(response) {
																component.log('Continue response: ' + JSON.stringify(response));
																if (component.client.handleError(response)) return;

																if (continueShowProgress) {
																	component.UI.showPanel('.panel-progress');
																}

																setTimeoutLightning(function() {
																   getStatus(jobId, continueShowProgress);
															    }, component.options.pollPause);
															});
														})
												);
										}
                                    } else {
                                        var files = [];

                                        for (var i = 0; i < response.job.files.length; i++) {
                                            var f = $.extend({}, response.job.files[i]);

                                            delete f.replaceable;

                                            if (!('fileUrl' in f)) {
                                                // We want auth params appended to the file urls before
                                                // passing them to the callback
                                                f.fileUrl = component.client.getFileUrl(f.relativeFileUrl, true);
                                            }

                                            files.push(f);
                                        }

                                        // Invoke callback method with data object containing copies of
                                        // files + data components of response.
                                        component.client.options.onCompleteCallback(
                                            component.client.withDefaultArgs({
                                                files: files,
                                                data: jQuery.extend({}, response.job.data),
                                                message: response.job.message
                                            }));
                                    }
                                }
                                if (isRdlc) {
                                    component.client.options.onProgressCallback(
                                        component.client.withDefaultArgs({ percent: response.job.percentComplete, message: response.job.message })
                                    );
                                    $A.getComponent(component.options.componentId).processDdpFinished();
                                }
                            });

                        }
                    });
                };

                component.client.options.onProgressCallback(
                    component.client.withDefaultArgs({ percent: 0, message: window.sendingRequestLabel }));

                component.client.run(data, function(response) {
                    this.complete = false;
                    component.log('Received response: ' + JSON.stringify(response));
                    if (component.client.handleError(response)) return;

                    if (response.cookie) {
                        component.client.options.cookie = response.cookie;
                    }
                    if (response.instance) {
                        component.client.options.instance = response.instance;
                    }
                    if (response.baseUrl) {
                        component.client.options.baseUrl = response.baseUrl;
                    }

                    component.currentRunId = response.jobId;
                    component.client.options.onProgressCallback(
                        component.client.withDefaultArgs({ percent: 0, message: window.processingRequestLabel }));

                    setTimeoutLightning(function() {
                        getStatus(response.jobId);
                    }, component.options.pollPause);
                });
            });
        };

        function processQueue() {
            // Get indices of jobs reporting completion
            var completedIndices = [];
            for (var i = 0; i < runner.jobs.running.length; i++) {
                if (runner.jobs.running[i].component.isComplete()) {
                    completedIndices.push(i);
                }
            }

            // Move any complete jobs to the complete array
            for (var i = completedIndices.length; i > 0; i--) {
                var removed = runner.jobs.running.splice(completedIndices[i - 1], 1);
                runner.jobs.complete.push.apply(runner.jobs.complete, removed);
            }

            while (runner.jobs.queued.length > 0 && runner.jobs.running.length < maxJobs) {
                var info = runner.jobs.queued.shift();

                run(info.component, info.data, info.styleUrl);

                runner.jobs.running.push(info);
            }

            setTimeoutLightning(processQueue, checkInterval);
        };

        processQueue();
    };

    DdpRunner.prototype.queueDdp = function(component, data, styleUrl) {
        this.loadCSS(styleUrl, function() {
            component.client.options.onProgressCallback(
                component.client.withDefaultArgs({ percent: 0, message: window.queuedLabel }));
        });

        this.jobs.queued.push({
            component: component,
            data: data,
            styleUrl: styleUrl
        });
    };

	if (!window.Drawloop) {
		window.Drawloop = {};
	}
	$.extend(window.Drawloop, {
        ddpRunner: new DdpRunner()
    });

    Drawloop.ProcessDdpComponent = function(options) {
        var component = this;

        this.$container = $('#' + options.containerId);

        // Accepts the name of a function and a default callback
        function wrapHandler(callbackFunctionName, defaultCallback) {
            return function() {
                if (typeof defaultCallback !== 'function') defaultCallback = function() { };

                var continueProcessing = true;

                if (typeof callbackFunctionName !== 'undefined' && typeof window[callbackFunctionName] === 'function') {
                    var tmp = window[callbackFunctionName].apply(window, arguments);

                    continueProcessing = tmp === undefined || !!tmp;
                }

                return continueProcessing && defaultCallback.apply(window, arguments);
            };
        };

        function onError(data) {
            var errorId = data.errorId;
            var message = data.message;

            component.UI.displayError(message + (errorId ? '<br/>' + window.includeThisErrorIdLabel + errorId : ''));
            component.UI.showPanel('.panel-error');
        };

        function onComplete(data) {
            var message = data.message;
            var additionalData = data.data|| { };
            var isRdlc = component.client.options.isRdlc;
            var isRdgFlow = component.client.options.isRdgFlow;

            // DocuSign delivery option returns a message containing only a redirect URI in
            // the case of embedded signing. If we find a URI, redirect the page to that.
            if (component.client.options.deliveryOptionType == 'DocuSign' && /https:\/\//.test(message)) {
                window.location = message;
                return;
            }

            if (message) {
                if (isRdlc) {
                    var runDdpComponent = $A.getComponent(component.client.options.componentId);

                    if (message.toLowerCase() == 'complete') {
                        runDdpComponent.ddpSuccessful(window.successYourRequestHasBeenCompletedLabel);
                    }
                    else {
                        runDdpComponent.ddpSuccessful(message);
                    }
                }
                else if (message.toLowerCase() != 'complete') {
                    alert(message);
                }
            }

            if (additionalData.returnUri) {
                if (!isRdlc && !isRdgFlow) {
                    window.location = additionalData.returnUri;
                }
                return;
            }

        };

        function updateProgress(data) {
            var percent = data.percent;
            var message = data.message;

            component.log('updating progress: ' + percent + ', ' + message);
            var $panel = component.$container.find('.panel-progress');
            var $prog = $panel.find('.progress');
            var $progInner = $panel.find('.progress-bar');
            var $progText = $panel.find('.progress-bar-text');

            if (!$panel.is(':visible')) {
                $panel.show();
            }

            if (!options.isRdlc || percent != 1) {
                message = message?.replace('looping', 'processing');
                if (options.ddpLabel) {
                    message = message?.replace('ddp', options.ddpLabel.toLowerCase());
                }
                $progText.text(message);
            }

            var tmp = $progInner.data('progress') || { progress: 0 };

            // If isRdlc, then we want the progress bar to jump to 0 for re-runs instead of animating to 0.
            var duration = options.isRdlc ? (percent != 0 ? 1000 : 0) : 300;

            $(tmp).stop(true).animate({ progress: percent }, {
                duration: duration,
                step: function() {
                    var newPercent = Math.round(this.progress * 100);
                    var width = Math.round($prog.width() * this.progress);

                    $prog.find('.progress-bar-inner').text(newPercent + '%');
                    $progInner.width(width);
                    $progInner.attr('aria-valuenow', newPercent);

                    $progInner.data('progress', tmp);
                },
                complete: function() {
                    var newPercent = Math.round(percent * 100);
                    var width = Math.round($prog.width() * percent);

                    $prog.find('.progress-bar-inner').text(newPercent + '%');
                    $progInner.width(width);
                    $progInner.attr('aria-valuenow', newPercent);

                    $progInner.data('progress', this);
                }
            });
        };

        this.options = $.extend({ timeout: 600000 }, options, {
            onErrorCallback:                wrapHandler(options.onErrorCallback, onError),
            onProgressCallback:             wrapHandler(options.onProgressCallback, updateProgress),
            onCompleteCallback:             wrapHandler(options.onCompleteCallback, onComplete),
        });

        $.extend(this, {
            log: function(msg) {
                component.debug && window.console && console.log && console.log(msg);
            },
            UI: {
                displayError: function (msg) {
                    var $con = $('<div class="alert alert-danger" role="alert" style="display: none;" />');

                    $con.append(
                        $('<div />').html(msg)
                    );

                    component.$container.find('.panel-error')
                        .html('')
                        .append($con);
                    $con.show();
                },
                showPanel: function(panelSelector) {
                    if (!component.options.isRdlc) {
                        component.$container
                            .find('.panel-progress, .panel-preview, .panel-error').hide();
                        component.$container.find(panelSelector).show();
                    }
                }
            },
            client: new Drawloop.DdpClient(this.options)
        });
    };

    Drawloop.ProcessDdpComponent.prototype.isComplete = function() {
        return this.client && this.client.complete;
    };

    Drawloop.DdpClient = function(options) {
        this.sessionId = options.sessionId;
        this.partnerServerUrl = options.partnerServerUrl;
        this.userId = options.userId;
        this.options = options;
        this.sandbox = options.sandbox;

        this.getUrl = function(method) {
            var hostname = this.options.baseUrl || this.options.endpoint || 'https://apps.drawloop.com';
            return hostname
                + (hostname.indexOf('/', hostname.length - 1) !== -1 ? '' : '/') // Add slash at the end if not present
                + 'salesforce/ddps/'
                + method;
        };

        var encodeParams = function(data) {
            return Object.keys(data).reduce(function(encodedParams, key) {
                // Encode all recipients or all email params
                if (key === 'recipients' || key === 'emailParams') {
                    return encodedParams.concat(JSON.parse(data[key]).map(function(subParam) {
                        return subParam.key + '=' + encodeURIComponent(subParam.value || '');
                    }));
                }

                // Encode single param
                return encodedParams.concat(key + '=' + encodeURIComponent(data[key] || ''));
            }, []);
        };

        if (!options.isRdlc) {
            /* In Classic, callout to distinct Apex methods for running and polling status of a DDP */
            /* Different server URLs, different methods */
            this.sendRequest = function(url, data, callback) {
                $.extend(data, {
                    sessionId: this.sessionId,
                    location: this.partnerServerUrl,
                    userId: this.userId,
                    sandbox: this.sandbox
                });

                if (url.indexOf('run', url.length - 'run'.length) >= 0) { // true when url ends with 'run'
                    // Add all params (except attachments) as query string params
                    var dataWithoutAttachments = $.extend({}, data);
                    delete dataWithoutAttachments.attachments;
                    url += '?' + encodeParams(dataWithoutAttachments).join('&');

                    // 'run' method will eventually be POSTed
                    Loop.ProcessDdpController.runDdp(
                        url,
                        'attachments=' + data.attachments, // Send `attachments` as POST request body to circumvent URL length limits
                        this.options.cookie || '',
                        function(result) {
                            callback(JSON.parse(result));
                        },
                        {
                            escape: false,
                            timeout: 120000 // Max timeout. 120 seconds === 2 minutes
                        }
                    );
                } else {
                    Loop.ProcessDdpController.pollDdp(
                        url,
                        encodeParams(data).join('&'),
                        this.options.cookie || '',
                        function(result) {
                            callback(JSON.parse(result));
                        },
                        {escape: false}
                    );
                }

            };
        }
        else {
            /* In Lightning, callout to the _same Apex method_ for running and polling status of a DDP */
            /* Different server URLs, same method */
            this.sendRequest = function(url, data, callback) {
                this.callback = callback;

                $.extend(data, {
                    sessionId: this.sessionId,
                    location: this.partnerServerUrl,
                    userId: this.userId,
                    sandbox: this.sandbox
                });

                var runDdpComponent = $A.getComponent(options.componentId);
                var processDdpComponent = runDdpComponent.find('processDdp');

                var action = processDdpComponent.get("c.pollDdp");
                action.setParams({
                    url: url,
                    jsonData: encodeParams(data).join('&'),
                    cookie: this.options.cookie || ''
                });
                action.setCallback(this, function(response) {
                    var runDdpComponent = $A.getComponent(this.options.componentId);
                    var message = window.anUnexpectedErrorHasOccurredLabel;
                    if (response.getState() === 'SUCCESS') {
                        var resultJson = response.getReturnValue();
                        var result = JSON.parse(resultJson);
                        if (result.status != 'success') {
                            if (result.message && result.errorId) {
                                message = result.message + ' ' + window.includeThisErrorIdLabel + result.errorId + '.';
                            }
                            if (result.status == 'error') {
                                runDdpComponent.set("v.errorMessage", message);

                                $A.util.addClass(runDdpComponent.find("documents"), "hidden");
                                $A.util.addClass(runDdpComponent.find("runDdpContainer"), "hidden");
                                $A.util.addClass(runDdpComponent.find("processDdpContainer"), "hidden");
                                $A.util.removeClass(runDdpComponent.find("errorContainer"), "hidden");
                                $A.util.removeClass(runDdpComponent.find("reRunButtons"), "hidden");
                            }
                        }
                    }
                    else {
                        var error = response.getError();
                        if (error && error[0] && error[0].message) {
                            message = response.getError()[0].message;
                        }
                        $A.util.addClass(runDdpComponent.find("runDdpContainer"), "hidden");
                        $A.util.addClass(runDdpComponent.find("processDdpContainer"), "hidden");
                        runDdpComponent.set("v.errorMessage", message);
                        $A.util.removeClass(runDdpComponent.find("errorContainer"), "hidden");
                        $A.util.removeClass(runDdpComponent.find("reRunButtons"), "hidden");
                    }

                    this.callback(result);
                });
                $A.enqueueAction(action);
            };
        }
    }

    Drawloop.DdpClient.prototype.withDefaultArgs = function(args) {
        return $.extend({
            containerId: this.options.containerId
        }, args);
    };

    Drawloop.DdpClient.prototype.run = function(data, callback) {
        $.ajaxSettings.traditional = true;

        this.sendRequest(this.getUrl('run'), data, callback);
    };

    Drawloop.DdpClient.prototype.handleError = function(response) {
        if (response.status == 'error') {
            this.options.onErrorCallback(
                this.withDefaultArgs({ errorId: response.errorId, message: response.message }));

            this.complete = true;
            return true;
        }

        return false;
    };

    Drawloop.DdpClient.prototype.getStatus = function(jobId, callback) {
        var data = {
            jobId: jobId
        };

        this.sendRequest(this.getUrl('getStatus'), data, callback);
    };

    Drawloop.DdpClient.prototype.continueRun = function(jobId, callback) {
        var data = {
            jobId: jobId
        };

        this.sendRequest(this.getUrl('Continue'), data, callback);
    };

    Drawloop.DdpClient.prototype.getResult = function(jobId, callback) {
        var data = {
            jobId: jobId
        };

        this.sendRequest(this.getUrl('getResult'), data, callback);
    };

    Drawloop.DdpClient.prototype.getFile = function(jobId, fileId, callback) {
        var data = {
            jobId: jobId,
            fileId: fileId
        };

        this.sendRequest(this.getUrl('getFile'), data, callback);
    };

    /**
     * Constructs a file URL using the given relative URL.
     *
     * Use the withAuthParams parameter to denote if the file URL requires
     * that authentication values be included. This is necessary when the auth
     * browser cookie is missing, which is set after making an authenticated
     * request to the DocGen server.
     *
     * @param {String} relativeFileUrl The relative URL pointing to the given file
     * @param {Boolean} withAuthParams Determines whether or not to include authentication values in file URL
     *
     * @return {String} The absolute URL to the specified file
     */
    Drawloop.DdpClient.prototype.getFileUrl = function(relativeFileUrl, withAuthParams) {
        withAuthParams = withAuthParams || false;
        var isRdlc = this.options.isRdlc;
        var isLightning = this.options.isLightning;
        var isOAuthEnabled = this.options.isOAuthEnabled;
        var baseUrl = this.options.baseUrl;

        var authParams = {};
        if (withAuthParams) {
            authParams['sessionId'] = this.sessionId;
            authParams['location'] = this.partnerServerUrl;

            if (isRdlc || isLightning || isOAuthEnabled) {
                authParams['userId'] = this.userId;
                authParams['sandbox'] = this.sandbox;
            }
        }

        var queryString = (!relativeFileUrl.includes('?') ? '?' : '')
            + (relativeFileUrl.includes('?') && !(relativeFileUrl.indexOf('&', relativeFileUrl.length - '&'.length) >= 0) ? '&' : '')
            + $.param(authParams);

        return baseUrl
            + relativeFileUrl
            + (withAuthParams ? queryString : '');
    };

    Drawloop.DdpClient.prototype.checkJobStatus = function(response, status) {
        return response && response.job && response.job.status && status && response.job.status.toLowerCase() === status.toLowerCase();
    };

    Drawloop.DdpClient.prototype.checkIsPauseToEditResponse = function(response) {
        if (!this.checkJobStatus(response, 'Paused')
            || !(response && response.job && response.job.files)) return false;

        for (var i = 0; i < response.job.files.length; i++) {
            if (response.job.files[i].replaceable) {
                return true;
            }
        }

        return false;
    };
})(jQuery);
