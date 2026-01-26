/**
 * @license Copyright (c) 2003-2017, CKSource - Frederico Knabben. All rights reserved.
 * For licensing, see LICENSE.md or http://ckeditor.com/license
 */

CKEDITOR.editorConfig = function( config ) {

    config.toolbar_basic = [
        [ 'Undo', 'Redo' ],
        [ 'Bold', 'Italic', 'Underline', 'Strike' ],
        [ 'NumberedList', 'BulletedList', '-', 'Outdent', 'Indent' ],
        [ 'Link', 'Unlink', 'Anchor' ]
    ];

    config.toolbar_full = [
        [ 'Source' ],
        [ 'PasteText', 'PasteFromWord', '-' , 'Undo', 'Redo' ],
        [ 'Scayt' ],
        '/',
        [ 'Bold', 'Italic', 'Underline', 'Strike', '-', 'RemoveFormat' ],
        [ 'NumberedList', 'BulletedList',
            '-', 'Outdent', 'Indent',
            '-', 'Blockquote', 'CreateDiv',
            '-', 'JustifyLeft', 'JustifyCenter', 'JustifyRight', 'JustifyBlock',
            '-', 'BidiLtr', 'BidiRtl', 'Language'
        ],
        [ 'Link', 'Unlink', 'Anchor' ],
        [ 'Image', 'Table', 'HorizontalRule', 'SpecialChar'],
        '/',
        [ 'Styles', 'Format', 'Font', 'FontSize' ],
        [ 'TextColor', 'BGColor' ],
        [ 'Maximize', 'ShowBlocks' ]
    ];

    config.toolbar_componentLibrary = [
        [ 'Undo', 'Redo' ],
        [ 'Bold', 'Italic', 'Underline', 'Strike', 'Superscript' ],
        [ 'TextColor', 'BGColor' ],
        [ 'JustifyLeft', 'JustifyCenter', 'JustifyRight' ],
        [ 'NumberedList', 'BulletedList', '-', 'Outdent', 'Indent' ],
        [ 'Link', 'Unlink', 'Image' ]
    ];

    // The basic controls come first, followed by all other controls.
    config.toolbar_fullSimple = [
        [ 'Undo', 'Redo' ],
        [ 'Bold', 'Italic', 'Underline', 'Strike' ],
        [ 'Link', 'Image' ],
        [ 'JustifyLeft', 'JustifyCenter', 'JustifyRight' ],
        [ 'NumberedList', 'BulletedList', 'Outdent', 'Indent' ],
        [
            'Unlink',
            'Anchor',
            'Source',
            'PasteText',
            'PasteFromWord',
            'Scayt',
            'RemoveFormat',
            'Blockquote',
            'CreateDiv',
            'JustifyBlock',
            'BidiLtr',
            'BidiRtl',
            'Language',
            'Table',
            'HorizontalRule',
            'SpecialChar',
            'Styles',
            'Format',
            'Font',
            'FontSize',
            'TextColor',
            'BGColor',
            'Maximize',
            'ShowBlocks'
        ]
    ];

    // Set default toolbar
    config.toolbar = 'basic';

    // remove bottom status bar elements by default
    config.removePlugins = 'elementspath';
    config.resize_enabled = false;

    // Simplify dialog windows
    config.removeDialogTabs = 'link:advanced';

};
