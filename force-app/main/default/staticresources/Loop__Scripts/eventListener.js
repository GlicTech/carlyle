(function() {
    if (window.Drawloop && window.Drawloop.eventListener) {
        return;
    }

    function handleLightningCallback(isLightningComponent, func) {
        if (isLightningComponent) {
            return $A.getCallback(func);
        } else {
            return func;
        }
    }

    function EventListener() {
        var isLightningComponent = typeof $A !== 'undefined';

        this.addEventListener = function(message, callback) {
            var onResponseMessage = handleLightningCallback(isLightningComponent, function(event) {
                var subdomain = window.location.hostname.split('.')[0];
                if (event.data.message === message &&
                    // Origin is Visualforce Page`
                    event.origin === window.location.origin ||
                    // Origin is Lightning Page
                    (event.origin.indexOf(subdomain) > -1 && (
                        event.origin.indexOf('visual.force.com') > -1
                        || event.origin.indexOf('lightning.force.com') > -1
                        || event.origin.indexOf('vf.force.com') > -1
                        || event.origin.indexOf('visualforce.com') > -1
                    ))
                ) {
                    callback = (function(originalCallback) {
                        function extendedCallback() {
                            originalCallback(event);

                            // Make sure these events are only called once.
                            if (window.removeEventListener) {
                                window.removeEventListener('message', onResponseMessage);
                            }
                            else if (window.detachEvent) {
                                window.detachEvent('message', onResponseMessage);
                            }
                        }

                        return extendedCallback;
                    })(callback);

                    callback(event);
                }
                else {
                    if (isLightningComponent) {
                        $A.warning('Invalid message or origin: ' + message);
                    }
                }
            });

            if (window.addEventListener) {
                window.addEventListener('message', onResponseMessage);
            }
            else if (window.attachEvent) {
                //this is the alternative to addEventListener for IE 6-10
                window.attachEvent('message', onResponseMessage);
            }
        };
    };

    if (!window.Drawloop) {
        window.Drawloop = {};
    }
    if (!window.Drawloop.eventListener) {
        window.Drawloop.eventListener = new EventListener();
    }
})();
