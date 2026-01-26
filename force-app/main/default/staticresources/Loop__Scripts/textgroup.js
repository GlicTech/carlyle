$(function(){
    //This resource holds the common functionality between the editTextGroup and editDdpTextGroup pages.
    (function(w){

        var date = new Date();
        var dateTime = date.getTime();
        var namespace = window.Loop ? 'loop__' : '';

        function createJSON(criteriaElements, inputAdvancedFilter) {

            function Criteria(){
                this.operator = '';
                this.operand1 = '';
                this.operand2 = '';
                this.ddp = '';
                this.object = '';
                this.field = '';
            };

            var criterias = [];
            var logic = [];
            var O_OR = 'OR';
            var O_AND = 'AND';
            var jsonString = '';
            var counterFilterError = 0;
            var filterError = false;

            criteriaElements.each(function() {
                var $elem = $(this);
                counterFilterError++;

                var object = $elem.find('.select-object').val();
                if(!$elem.find('.select-field').attr('disabled') && object) {
                    var field = $elem.find('.select-field').val();
                    var filter =  new Criteria();
                    filter.operator = $elem.find('.select-operator').val();
                    filter.operand1 = window.UTILS.mapOF[object].fieldsAndTags[field].fieldTag;
                    filter.operand2 = $elem.find('.filter-compare-to-input').val();
                    filter.ddp = $elem.find('.select-ddp').val();
                    filter.object = object;
                    filter.field = field;

                    criterias.push(filter);
                } else {
                    $elem.find('.select-object').val('None');
                    $elem.find('.select-field').attr('disabled', 'disabled');
                    $elem.find('.select-operator').attr('disabled', 'disabled');
                    $elem.find('.operand2').attr('disabled', 'disabled');
                    window.UTILS.handleMSG('slds-theme--error','Object in filter '+ counterFilterError +' can not be --None--');
                    filterError = true;
                }
            });

            if(filterError) return 'Error';
            if (criterias.length > 1) {
                // Remove all whitespace
                inputAdvancedFilter = inputAdvancedFilter.replace(/\s/g, '');

                if (!inputAdvancedFilter) {
                    var criteriaNumbers = [];
                    for (var i = 1; i <= criterias.length; i++) {
                        criteriaNumbers.push(i);
                    }
                    inputAdvancedFilter = 'AND(' + criteriaNumbers.join(',') + ')';
                }

                if (!inputAdvancedFilter.toUpperCase().startsWith(O_OR) && !inputAdvancedFilter.toUpperCase().startsWith(O_AND)) {
                    window.UTILS.handleMSG('slds-theme--error','Advanced filter format must be like AND(1,OR(2,3))');
                    return 'Error';
                }

                var numbers = inputAdvancedFilter.match(/\d+/g);

                // Make sure all filters are included in logic
                var missingNumbers = [];
                for (var i = 1; i <= criterias.length; i++) {
                    if (numbers.indexOf(i.toString()) == -1) {
                        missingNumbers.push(i);
                    }
                }
                if (missingNumbers.length > 0) {
                    window.UTILS.handleMSG('slds-theme--error','Advanced filter format must include every filter number. Missing: ' + JSON.stringify(missingNumbers));
                    return 'Error';
                }

                // Prevent numbers referencing filters that do not exist
                var extraNumbers = [];
                for (var i = 0; i < numbers.length; i++) {
                    if (numbers[i] > criterias.length) {
                        extraNumbers.push(+numbers[i]);
                    }
                }
                if (extraNumbers.length > 0) {
                    window.UTILS.handleMSG('slds-theme--error','Advanced filter format includes numbers for filters that do not exist. Extra Numbers: ' + JSON.stringify(extraNumbers));
                    return 'Error';
                }

                // Convert to JSON
                inputAdvancedFilter = inputAdvancedFilter.replace(/AND\(/gi, '["AND",');
                inputAdvancedFilter = inputAdvancedFilter.replace(/OR\(/gi, '["OR",');
                inputAdvancedFilter = inputAdvancedFilter.replace(/\)/g, ']');

                // replace numbers with criteria
                inputAdvancedFilter = inputAdvancedFilter.replace(/\d+/g, function(match, i, s) {
                    return JSON.stringify(criterias[+match - 1]);
                });

                try {
                    logic = JSON.parse(inputAdvancedFilter);
                    jsonString = inputAdvancedFilter;
                } catch (error) {
                    window.UTILS.handleMSG('slds-theme--error','Advanced filter format must be like AND(1,OR(2,3))');
                    return 'Error';
                }
            } else if (criterias.length == 1) {
                jsonString = JSON.stringify(criterias[0]);
            }

            return jsonString;
        }

        function closeModal(name) {
            $('#'+name).removeClass(window.UTILS.sldsFadeInOpen_Class);
            $('#'+name+'_background').removeClass(window.UTILS.sldsModalBackdropOpen_Class);
        }

        function handleException(classToApply , msg) {
            $('#msgSection').empty();
            $notificationElement = $(w.UTILS.notificationHTML);
            $notificationElement.find('#notificationA').addClass(classToApply);
            $notificationElement.find('#messagesContainer').text(msg);
            $('#msgSection').append($notificationElement);
        }

        $.extend(w.UTILS, {
            objects : [],
            mapOF   : {},
            objectsOptionsHTML : '',
            handleMSG : handleException,
            closeModal : closeModal,
            generateFilterJSON : createJSON,
            notificationHTML:
                            '<div class="slds-notify-container">'+
                                '<div id="notificationA" class=" slds-notify slds-notify--alert slds-theme--inverse-text slds-theme--alert-texture" role="alert">'+
                                    '<span class="slds-assistive-text">Error</span>'+
                                    '<button class="closeNotification slds-button slds-button--icon-inverse slds-notify__close">'+
                                        '<svg aria-hidden="true" class="slds-button__icon">'+
                                            '<use xlink:href="/resource/'+dateTime+'/' + namespace + 'SalesforceLightning/assets/icons/action-sprite/svg/symbols.svg#remove" xmlns:xlink="http://www.w3.org/1999/xlink"></use>'+
                                        '</svg>'+
                                        '<span class="slds-assistive-text">Close</span>'+
                                    '</button>'+
                                    '<h2 id="messagesContainer">Base System Alert</h2>'+
                                '</div>'+
                            '</div>',
            sldsFadeInOpen_Class : 'slds-fade-in-open',
            sldsModalBackdropOpen_Class : 'slds-backdrop_open',
            filterTableHTML :
                            '<div class="conditionFilters-container" >' +
                                '<table id="filter-table">' +
                                    '<tr>' +
                                        '<td/>' +
                                        '<td class="filter-data" id="select-ddp-cell">' +
                                            '<label class="slds-form-element__label">{DocumentPackageLabel}</label>' +
                                        '</td>' +
                                        '<td class="filter-data">' +
                                            '<label class="slds-form-element__label">Object</label>' +
                                        '</td>' +
                                        '<td class="filter-data">' +
                                            '<label class="slds-form-element__label">Field</label>' +
                                        '</td>' +
                                        '<td class="filter-data">' +
                                            '<label class="slds-form-element__label">Operator</label>' +
                                        '</td>' +
                                        '<td class="filter-data">' +
                                            '<label class="slds-form-element__label" style="margin-right: 5px;">Value</label>' +
                                            '<button class="help-icon slds-button slds-button--icon-bare slds-m-right--xx-small" style="top: 1px;">' +
                                                '<svg aria-hidden="true" class="default-cursor slds-button__icon">' +
                                                    '<use xlink:href="/resource/' + dateTime + '/' + namespace + 'SalesforceLightning/assets/icons/utility-sprite/svg/symbols.svg#info" class="default-cursor"></use>' +
                                                '</svg>' +
                                                '<span class="slds-assistive-text">Help</span>' +
                                                '<div class="slds-popover slds-popover--tooltip slds-nubbin--bottom-left lowTip" role="tooltip" id="toolTip">' +
                                                    '<div class="slds-popover__body">Use the Field Tagger for dynamic values.</div>' +
                                                '</div>' +
                                            '</button>' +
                                        '</td>' +
                                        '<td/>' +
                                    '</tr>' +
                                '</table>' +
                            '</div>',
            filterTableRowHTML :
                            '<tr class="filter-row">' +
                                '<td class="filter-data">' +
                                    '<span class="slds-icon__container filter-count-container" style="float:right; background:#7dc37d;">' +
                                        '<div class="filter-count">1</div>' +
                                    '</span>' +
                                '</td>' +
                                '<td class="filter-data filter-data-field">' +
                                    '<div class="slds-form-element">' +
                                        '<div class="slds-form-element__control">' +
                                            '<select class="select-ddp slds-select">' +
                                                '<option value="None">--None--</option>' +
                                            '</select>' +
                                        '</div>' +
                                    '</div>' +
                                '</td>' +
                                '<td class="filter-data filter-data-field">' +
                                    '<div class="slds-form-element">' +
                                        '<div class="slds-form-element__control">' +
                                            '<select class="select-object slds-select">' +
                                                '<option value="None">--None--</option>' +
                                            '</select>' +
                                        '</div>' +
                                    '</div>' +
                                '</td>' +
                                '<td class="filter-data filter-data-field">' +
                                    '<div class="slds-form-element">' +
                                        '<div class="slds-form-element__control">' +
                                            '<select class="select-field slds-select">' +
                                                '<option value="None">--None--</option>' +
                                            '</select>' +
                                        '</div>' +
                                    '</div>' +
                                '</td>' +
                                '<td class="filter-data filter-data-field">' +
                                    '<div class="slds-form-element">' +
                                        '<div class="slds-form-element__control">' +
                                            '<select class="select-operator slds-select">' +
                                                '<option value="equals">equals</option>' +
                                                '<option value="not equal to">not equal to</option>' +
                                                '<option value="starts with">starts with</option>' +
                                                '<option value="ends with">ends with</option>' +
                                                '<option value="contains">contains</option>' +
                                                '<option value="does not contain">does not contain</option>' +
                                                '<option value="less than">less than</option>' +
                                                '<option value="greater than">greater than</option>' +
                                                '<option value="less or equal">less or equal</option>' +
                                                '<option value="greater or equal">greater or equal</option>' +
                                                '<option value="includes">includes</option>' +
                                                '<option value="excludes">excludes</option>' +
                                                '<option value="is blank">is blank</option>' +
                                            '</select>' +
                                        '</div>' +
                                    '</div>' +
                                '</td>' +
                                '<td class="filter-data filter-data-field">' +
                                    '<div class="slds-form-element">' +
                                        '<div class="slds-form-element__control">' +
                                            '<input class="operand2 filter-compare-to-input slds-input" type="text">' +
                                        '</div>' +
                                    '</div>' +
                                '</td>' +
                                '<td class="filter-data">' +
                                    '<span class="remove-filter slds-button_icon">' +
                                        '<svg aria-hidden="true" class="slds-icon icon__svg slds-icon-action-delete" style="padding:4px; height:1.5rem; width:1.5rem;">' +
                                            '<use xlink:href="/resource/' + dateTime + '/' + namespace + 'SalesforceLightning/assets/icons/action-sprite/svg/symbols.svg#delete" class="default-cursor"></use>' +
                                        '</svg>' +
                                    '</span>' +
                                '</td>' +
                            '</tr>',
            filterTableRowErrorHTML :
                                '<tr class="filter-error">' +
                                    '<td/>' +
                                    '<td colspan="5" class="filter-data" style="color:rgb(194, 57, 52);">{error}</td>' +
                                    '<td/>' +
                                '</tr>',
            filterCriteriaHTML : '<div class="filter-criteria-container" id="filterCriteriaContainer"></div>',
            removeFilterHTML : '<span class="remove-filter"><svg aria-hidden="true" class="slds-icon slds-icon--small slds-icon-text-default"><use xlink:href="/resource/'+ date.getTime() +'/' + namespace + 'SalesforceLightning/assets/icons/utility-sprite/svg/symbols.svg#close"></use></svg></span>'
        })
    })(window);
});
