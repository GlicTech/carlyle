(function( $ ){
	// Add support for String.format (from http://stackoverflow.com/questions/610406/javascript-equivalent-to-printf-string-format#answer-4673436)
	if (!String.format) {
	  String.format = function (format) {
		var args = Array.prototype.slice.call(arguments, 1);
		var sprintf = function (match, number) {
		  return number in args ? args[number] : match;
		};

		var sprintfRegex = /\{(\d+)\}/g;

		return format.replace(sprintfRegex, sprintf);
	  };
	}

	var log = function(msg) { window.console && window.console.log(msg); }
	var requireOption = function(name, op) { if (op === undefined) throw "The option '" + name + "' is required."; }
	var parseQueryString = function(url) {
		var i = url.indexOf('?'),
		    tmp = i === -1 ? url : url.substring(i + 1),
		    qs = {},
			sections = tmp.split('&');
		for (var i = 0; i < sections.length; i++) {
			if (!sections[i]) continue;
			var pair = sections[i].split('=');
			if (pair[0] in qs) {
				qs[pair[0]] = (qs[pair[0]] || '') + ',' + decodeURIComponent(pair[1] || '');
			} else {
				qs[pair[0]] = decodeURIComponent(pair[1] || '');
			}
		}
		return qs;
	}

	// Method calling logic
	var initPluginWithMethods = function(methods) {
		return (function(method) {
	    	if ( methods[method] ) {
	      		return methods[ method ].apply( this, Array.prototype.slice.call( arguments, 1 ));
	    	} else if ( typeof method === 'object' || ! method ) {
	      		return methods.init.apply( this, arguments );
	    	} else {
	      		$.error( 'Method ' +  method + ' does not exist on jQuery.drawloop' );
	    	}
    	});
	}

	// Plugin enables shift-click functionality for checkboxes
	var fnName = 'shiftClickify';
	$.fn.shiftClickify = initPluginWithMethods({
		'init': function() {
			var $elems = this;
			var f = function(e) {
				var prev = $elems.data(fnName + '.previous');
	            if (e.shiftKey && prev) {
	                var index = $elems.index(this),
	                    prevIndex = $elems.index(prev);
	                $elems.slice(Math.min(index, prevIndex), Math.max(index, prevIndex) + 1).not(this).attr('checked', this.checked);
	            }
	            $elems.data(fnName + '.previous', this);
	        };
			return this.unbind('.' + fnName).bind('click.' + fnName, f);
		},
		'destroy': function() {
			return this.unbind('.' + fnName);
		}
	});

	$.extend({
		// Plugin enables support for testing and granting OAuth access to
		// the LOOP_Document_Services Connected App
		authorize: initPluginWithMethods({
			init: function(options) {
				var plugin = this.authorize;
				var qs = parseQueryString(window.location.href);
				plugin.options = {
					// functions
					verifyError: null,
					verifySuccess: null,
					authFlowComplete: null,
					onChangeRequiresAuth: null,
					onChangeRequestingAuth: null,

					promptLogin: false,
					promptConsent: false,
					sandbox: false,
					autoVerify: true,
					appOrigin: 'https://apps.drawloop.com'
				};
				plugin.requiresAuthorization = false;
				plugin.requestingAuthorization = false;
				$.extend(plugin.options, options);
				requireOption('accessToken', plugin.options.accessToken);
				requireOption('userId', plugin.options.userId);

				var setRequiresAuth = function(requires) {
					plugin.requiresAuthorization = requires;
					plugin.options.onChangeRequiresAuth && plugin.options.onChangeRequiresAuth(requires);
				};
				var setRequestingAuth = function(requesting) {
					plugin.requestingAuthorization = requesting;
					plugin.options.onChangeRequestingAuth && plugin.options.onChangeRequestingAuth(requesting);
				};
				var verify = function() {
					setRequestingAuth(true);
					var url = plugin.options.appOrigin + '/salesforce/auth';
					plugin.getJSONCrossDomain(url, plugin.verifyCallback, function (error) {
						plugin.options.verifyError && plugin.options.verifyError(error);
					});
					/*$.ajax({
						url: url,
						cache: false,
						async: true,
						crossDomain: true,
						dataType: 'jsonp',
						success: plugin.verifyCallback,
						error: (function(jqXHR, textStatus, errorThrown) { alert(errorThrown); })
					});
					$.ajax({
						url: url,
						cache: false,
						async: true,
						crossDomain: true,
						dataType: 'text',
						dataFilter: function(data, type) {
							return plugin.interpretResponse(tmp);
						},
						success: plugin.verifyCallback,
						error: (function(jqXHR, textStatus, errorThrown) { alert(errorThrown); })
					});*/
				};
				plugin.sendXDomainRequest = function(url, postData, onsuccess, onerror) {
					var xdr = new XDomainRequest();
					xdr.onload = function() { onsuccess && onsuccess(xdr.responseText); };
					xdr.onerror = function() { onerror && onerror(xdr.responseText); };
					xdr.onprogress = function() { };
					xdr.ontimeout = function() { };
					xdr.open('POST', url);
					xdr.send(postData);
					return xdr;
				};
				plugin.getJSONCrossDomain = function(url, onsuccess, onerror) {
					var callbackName = plugin.generateAuthorizationFlowCallback();
					var postData = {
						accessToken: plugin.options.accessToken,
						userId: plugin.options.userId,
						next: plugin.getNextUrl(callbackName),
						sandbox: plugin.options.sandbox
					};

					if (!jQuery.support.cors && window.XDomainRequest) {
						// At least IE 8 - 10
						plugin.sendXDomainRequest(url, postData, function(responseStr) {
							var data = plugin.interpretResponse(responseStr);
							onsuccess && onsuccess(data);
						}, onerror);
					} else {
						$.ajax({
							url: url,
							cache: false,
							async: true,
							crossDomain: true,
							method: 'POST',
							data: postData,
							dataType: 'json',
							success: onsuccess,
							error: function (jqXHR, textStatus, errorThrown) { onerror && onerror(errorThrown); } // Attempting to be consistent with IE implementation, but consistently worse...
						});
					}
				};

				plugin.interpretResponse = function(data) {
					var jsonpRegex = /^[\d\D]*\((.*)\);?$/,
						tmp = data;
					if (jsonpRegex.test(tmp)) {
						tmp = jsonpRegex.exec(tmp)[1];
					}
					return JSON.parse(tmp);
				};
				plugin.verifyCallback = function(dataStr) {
					var data = typeof dataStr === 'string' ? plugin.interpretResponse(dataStr) : dataStr;
					plugin.verifyResponse = data;
					setRequestingAuth(false);
					var response = data.Response ? data.Response.toLowerCase() : null;
					if (!response) {
						plugin.options.verifyError && plugin.options.verifyError(data);
					} else if (response == 'error') {
						plugin.options.verifyError && plugin.options.verifyError(data);
					} else if (response == 'redirect' || response == 'authenticated') {
						if (response == 'redirect') {
							setRequiresAuth(true);
						}
						plugin.options.verifySuccess && plugin.options.verifySuccess(data);
					}
				};
				plugin.generateAuthorizationFlowCallback = function() {
					var funcName = 'func' + Math.round(Math.random() * 100000);
					window[funcName] = function(data) {
						var qs = parseQueryString(data);
						var result = {
							status: qs.error ? 'error' : 'success',
							url: data
						}
						if (qs.error) {
							result.error = qs.error;
							result.error_description = qs.error_description;
						}
						if (result.status == 'success') {
							setRequiresAuth(false);
						}
						plugin.options.authFlowComplete && plugin.options.authFlowComplete(result, plugin.authFlowCompleteParams);
						delete plugin.authFlowCompleteParams;
					};
					return funcName;
				};
				plugin.getNextUrl = function(callback) {
					return window.location.protocol + '//' + window.location.hostname + '/apex/loop__looplus?callback=' + callback;
				};
				plugin.getSalesforceAuthUrl = function(clientId, redirectUri, state) {
					var prompt = [];
					if (plugin.options.promptLogin) prompt.push('login');
					if (plugin.options.promptConsent) prompt.push('consent');
					return 'https://' + (plugin.options.sandbox ? 'test' : 'login') + '.salesforce.com/services/oauth2/authorize?response_type=code&client_id=' + encodeURIComponent(clientId) + '&redirect_uri=' + encodeURIComponent(redirectUri) + '&state=' + encodeURIComponent(state) + (prompt.length ? '&prompt='+encodeURIComponent(prompt.join(' ')) : '');
				};

				if (plugin.options.autoVerify) {
					verify();
				}
			},
			verify: function() {
				verify();
			},
			launchAuthorizationFlow: function(authFlowCompleteParams) {
				var plugin = this.authorize;
				if (plugin.requestingAuthorization) {
					throw 'Currently requesting authorization.  You must wait for this request to complete before launching the authorization flow.';
				}
				if (!plugin.verifyResponse) {
					throw 'You must call the verify method before using this method.';
				}
				plugin.authFlowCompleteParams = authFlowCompleteParams;
				window.open(plugin.getSalesforceAuthUrl(plugin.verifyResponse.ClientId, plugin.verifyResponse.RedirectUri, plugin.verifyResponse.State), 'SalesforceAuthWindow', 'width=902, height=680');
			},
			getStatus: function() {
				var plugin = this.authorize;
				return {
					requiresAuthorization: plugin.requiresAuthorization,
					requestingAuthorization: plugin.requestingAuthorization
				};
			}
		}),

		// Notif-IE plugin enables support for checking if browser is IE in compatibility view, or doesn't meet
		// specified IE version
		notifie: initPluginWithMethods({
			init: function(options) {
				var plugin = this.notifie;
				plugin.options = {
					allowCompatibilityView: true,
					requiredVersion: -1,
					requiredBrowserModeVersion: -1,
					requiredDocumentModeVersion: -1,
					containerSelector: null,
					compatibilityViewHelpLink: 'http://support.drawloop.com/lds/faq/ie-compatibility/',
                    compatibilityViewMessage: 'You are viewing this page in Internet Explorer Compatibility View.  You may need to disable Compatibility View for this page to work properly.',
					versionMessage: 'You appear to be on an older version of Internet Explorer.  This page requires Internet Explorer {0} to function properly.  Please upgrade your browser to a later version.'
				};
				$.extend(plugin.options, options);

				plugin.versionMatch = /MSIE (\d+(\.\d+))/;
				plugin.tridentMatch = /Trident\/(\d+(\.\d+))/;

				plugin.requiresCallback = function() {
					var info = plugin.getIEInfo();
					return info.isIE &&
						(
							plugin.options.requiredVersion > info.version ||
							plugin.options.requiredBrowserModeVersion > info.browserModeVersion ||
							plugin.options.requiredDocumentModeVersion > info.documentModeVersion ||
							(!plugin.options.allowCompatibilityView && info.isCompatibilityView)
						);
				};

				plugin.addMessage = function(msg, type, helpLink) {
					var container = plugin.options.containerSelector;
					var $msgs = $('#notifie_messages');
					if (!$msgs.length) {
						$msgs = $('<div id="notifie_messages" />');
						$(container).append($msgs);
					}

					$msgs.append(
						$('<div class="message" />')
							.addClass((type || 'info') + 'M3')
							.append(
								$('<table class="messageTable" cellspacing="0" cellpadding="0" style="padding:0;margin:0;"></table>')
									.append(
										$('<tr/>')
											.append('<td><img class="msgIcon" src="/s.gif" /></td>')
												.append(
													$('<td class="messageCell" />')
														.append(
															$('<div class="messageText" />')
																.append(msg)
																.append(helpLink ?
																	$('<span class="helpButtonOn" id="notifie.help-_help"></span>')
																		.append(
																			$(String.format('<a href="{0}" target="_blank" />',helpLink))
																				.append('<img src="/s.gif" alt="" class="helpOrb" title="" />')
																		)
																	: ''
																)
														)
												)
											)
									)
							);
				};

				plugin.getIEInfo = function() {
					var info = {
						isIE: false,
						isCompatibilityView: false,
						version: -1,
						browserModeVersion: -1,
						documentModeVersion: -1
					};
					if (!plugin.versionMatch.test(navigator.userAgent)) return info;

					info.isIE = true;
					var tridentMatch = plugin.tridentMatch.exec(navigator.userAgent);
					var hasTrident = tridentMatch !== null,
						tridentVersion = tridentMatch ? +(tridentMatch[1]) : -1;

					info.version = info.browserModeVersion = +(plugin.versionMatch.exec(navigator.userAgent)[1]);

					// Might want to handle if documentMode == 0 (page has not finished loading yet)
					info.documentModeVersion = typeof document.documentMode !== 'undefined' ? document.documentMode : -1;
					if (!hasTrident) {
						info.version = 7;
					} else if (tridentVersion == 4) {
						info.version = 8;
					} else if (tridentVersion == 5) {
						info.version = 9;
					} else if (tridentVersion == 6) {
						info.version = 10;
					}
					// If our method for determining actual IE version via Trident version is wrong
					// and the reported version is higher, fall back to using that.
					if (info.browserModeVersion > info.version) {
						info.version = info.browserModeVersion;
					}
					info.isCompatibilityView = info.version != info.browserModeVersion ||
						info.version != info.documentModeVersion;
					return info;
				};

				if (plugin.requiresCallback()) {
					var info = plugin.getIEInfo();
					if (plugin.options.containerSelector) {
						if (info.isCompatibilityView) {
							plugin.addMessage(plugin.options.compatibilityViewMessage, 'warning', plugin.options.compatibilityViewHelpLink);
						} else {
							plugin.addMessage(
								String.format(plugin.options.versionMessage,
									Math.max(plugin.options.requiredVersion, plugin.options.requiredBrowserModeVersion, plugin.options.requiredDocumentModeVersion))
								, 'warning');
						}
					}
					if (plugin.options.callback) {
						plugin.options.callback.apply(plugin, [ info.isCompatibilityView, info.version, info.browserModeVersion, info.documentModeVersion ]);
					}
				}
			}
		}),

		// messenger plugin handled message passing cross-frame (or tab/window for browsers that allow it)
		messenger: initPluginWithMethods({
			init: function(options) {
				var plugin = this.messenger;
				plugin.options = {
					endpoint:	null,
					window:		null,
					onReceive: 	$.noop
				};
				$.extend(plugin.options, options);

				if (plugin.options.onReceive) {
					// Only generate method once, so we can have a single reference
					// to remove via removeEventListener / detachEvent
					if (!$.data(plugin, 'receiveMessage')) {
						$.data(plugin, 'receiveMessage', function(event) {
							if (event.origin !== plugin.options.endpoint)
								return;

							var data = event.data;
							try {
								data = $.parseJSON(data);
							} catch (ex) { }

							plugin.options.onReceive.apply(this, [ data, event ]);
						});
					}
					var receiveMessage = $.data(plugin, 'receiveMessage');

					// Make sure this method only gets attached once
	                if (window.addEventListener)
	                {
						window.removeEventListener('message', receiveMessage, false);
	                    window.addEventListener('message', receiveMessage, false);
	                }
	                else
	                {
						window.detachEvent('onmessage', receiveMessage);
	                    window.attachEvent('onmessage', receiveMessage);
	                }
				}
			},

			send: function(msg) {
				var plugin = this.messenger;
				if (!plugin.options.endpoint) throw 'No endpoint set as a destination for sending messages.';
				if (!plugin.options.window) throw 'No window set to send messages to';

				// Message must be passed as a string for at least some versions of IE
				if (typeof msg !== 'string') {
					msg = window.JSON && JSON.stringify
						? JSON.stringify(msg)
						: '' + msg;
				}

				plugin.options.window.postMessage(msg, plugin.options.endpoint);
			}
		})
	});

	// Plugin for Drawloop functionality
	var dl_methods = {
		shiftClickify: $.fn.shiftClick
	};
	$.fn.drawloop = initPluginWithMethods(dl_methods);
})( jQuery );
