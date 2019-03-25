'use strict';

var Storage = function() {

};

Storage.prototype = {
    setObject: function(key, value) {
        this.setParam(key, JSON.stringify(value));
    },

    getObject: function(key, defaultValue) {
        var json = this.getParam(key, defaultValue);

        if (json === null) {
            return {};
        }

        return (typeof json === 'object')
            ? json
            : JSON.parse(json);
    },
    setParam: function(key, value) {
        window.sessionStorage.setItem(key, value);
    },
    getParam: function(key, defaultValue) {
        return (window.sessionStorage.getItem(key) === null && typeof defaultValue !== 'undefined')
            ? defaultValue
            : window.sessionStorage.getItem(key);
    },
    removeParam: function(key) {
        window.sessionStorage.removeItem(key);
    }
};

'use strict';
/* globals Storage, jQuery, autocomplete, document, $, window */

var Search = function() {
    Storage.apply(this, arguments);

    this.timeoutDelay = 300;
    this.searchUrl = null;
};

function getCookie(cname) {
    var name = cname + "=";
    var decodedCookie = decodeURIComponent(document.cookie);
    var ca = decodedCookie.split(';');
    for(var i = 0; i <ca.length; i++) {
        var c = ca[i];
        while (c.charAt(0) == ' ') {
            c = c.substring(1);
        }
        if (c.indexOf(name) == 0) {
            return c.substring(name.length, c.length);
        }
    }
    return "";
}

function openInNewTab(url){
    var win = window.open(url, "_blank");
    win.focus();
}

Search.prototype = {
    '__proto__': Storage.prototype,
    setBasedir: function(basedir) {
        //this.searchUrl = basedir + 'server.php'; //WTF?
    },

    getAjaxDeferred: function() {
        var def = $.Deferred();
        function timeoutFunc() {
            if ( $.active === 0 ) {
                def.resolve();
            } else {
                window.setTimeout( timeoutFunc, 200 );
            }
        }
        timeoutFunc();
        return def;
    },


    toggleBlurryOverlay: function() {
        $('#overlay').toggleClass('gray-out-overlay');
    },

    hideLoadingAfterLoad: function() {
        this.toggleBlurryOverlay();
        this.getAjaxDeferred()
            .done( function() {
                $('#-js-loading').hide();
            });
    },

    showLoading: function() {
        this.toggleBlurryOverlay();
        $('#-js-loading').show();
    },

    autocomplete: function() {
        var self = this;
        if (this.searching) {
            return;
        }
        jQuery.ajax({
            url: "/search/autocompletion/",
            headers: {
                "X-CSRFToken": getCookie("csrftoken")
            },
            data: {
                'source': self.getParam('source'),
                'terms':  self.getParam('terms'),
                'type': 'autocomplete'
            },
            type: 'post',
            dataType: 'json',
            success: function(data) {
                self.parseAutocompleteResult(data);
            }
        });
    },
    find: function() {
        var self = this;
        this.searching = true;

        var terms = this.getParam('terms');
        terms = terms.split(' ');
        terms = terms.filter(function(val) {
            return val !== '';
        });
        terms = terms.join(',');

        this.showLoading();
        jQuery.ajax({
            url: "/search/search/",
            headers: {
                "X-CSRFToken": getCookie("csrftoken")
            },
            data: {
                'source': self.getParam('source'),
                'type': 'results',
                'terms': terms,
                'extended': self.getParam('extended'),
                'page-geoportal': self.getParam('pages'),
                'data-geoportal': self.getParam('data-id'),
                'keywords':  self.getParam('keywords'),
                'resources': self.getParam('resources'),
                'facet': self.getParam('facet'),
                'orderBy': self.getParam('orderBy'),
                'spatial': self.getParam('spatialSearch'),
                'searchBbox': self.getParam('searchBbox'),
                'searchTypeBbox': self.getParam('searchTypeBbox'),
                'onlyOpenData': self.getParam('onlyOpenData')
            },
            type: 'post',
            dataType: 'json',
            success: function(data) {
                self.parseSearchResult(data);
                if(self.getParam("source") != "info"){
                    startInfoCall();
                }
            },
            timeout: 60000,
            error: function(jqXHR, textStatus, errorThrown){
                if(textStatus === "timeout"){
                    alert("A timeout occured.");
                }else{
                }
            },
        })
            .always(function() {
                self.hideLoadingAfterLoad();
                self.searching = false;
                self.setParam("facet", "");
                self.setParam("keywords", "");
                self.setParam("searchBbox", "");
                self.setParam("searchTypeBbox", "");
                toggleSearchArea();
                openSpatialArea();
                enableSearchInputField();
                focus_on_search_input();
            });
    },

    parseSearchResult: function(data) {
        var self = this;

        if (data === null) {
            return false;
        }

        if (typeof data.html !== 'undefined') {
            if(!$("#search-results").hasClass("active")){
                $("#search-results").toggleClass("active");
            }
            jQuery('#search-results .-js-result').html(data.html);
        }

        // see if pagination was used than display the current resource the user has used the paginator
        var sPaginated = self.getParam('paginated');

        // if user has used the pagination we display the current resource body
        if (sPaginated === 'true') {
            var sResourceId = self.getParam('data-id');
            var sResourceBody = '.' + sResourceId + '.search--body';

            var $title = jQuery(sResourceBody)
                            .closest('.search-cat')
                            .find('.search-header')
                            .find('.source--title')
            ;
            $title.click(); //execute the accordion because of the icon
        }

        //set the paginator back to false
        self.setParam('paginated', false);

        $('.-js-resource').addClass('inactive');
        $('#geoportal-search-extended-what input').prop('checked', null);
        var selectedResources = data.resources;
        $.each(selectedResources, function(resource) {
            var resource = selectedResources[resource];
            $('[data-resource=' + resource + ']').removeClass('inactive');
            var r = resource.charAt(0).toUpperCase() + resource.slice(1);
            $('#geoportal-checkResources' + r).prop('checked', true);
        });

        return undefined;
    },

    parseAutocompleteResult: function(data) {
        autocomplete.show(data.resultList);
    },
    parseQuery: function() {
        var self = this;
        var url = document.URL;
        var query = [];

        if (url.indexOf("?") !== -1) {
            url = url.substr(url.indexOf("?") + 1);
            url = url.split("&");

            for (var i = 0; i < url.length; i++) {
                var tmp = url[i].split("=");
                query[tmp[0]] = encodeURIComponent(tmp[1]);
            }
        }
        return query;
    },
    hide: function() {
        $('.-js-result').addClass("hide");
    },
    show: function() {
        $('.-js-result').removeClass("hide");
    }
};

'use strict';
/* globals jQuery, Search, BASEDIR, setTimeout, L, document, window, $ */

/**
 * init
 */
var autocomplete,
    prepareAndSearch = null;
var maps = []; //used for "raemliche Eingrenzung"

/**
 * Searchfield simple search function
 * @type {Search}
 */
var search = new Search();
search.setBasedir(BASEDIR);

/**
 * Autocomplete feature for searchfield
 * @param search
 * @constructor
 */
var Autocomplete = function(search) {
    var self = this;
    var _search = null;
    var _minLength = 1;
    var _input = null;
    var _div = null;
    var _pos = 0;
    var KEYBOARD = {
        UP_ARROW: 38,
        DOWN_ARROW: 40,
        LEFT_ARROW: 37,
        RIGHT_ARROW: 39,
        ENTER: 13
    };

    this.init = function(search) {
        var self = this;
        _search = search;
        _input = jQuery('.-js-simple-search-field');
        _div = jQuery('.-js-simple-search-autocomplete');
        _div.on('click', self.onSelect);
        _input.on('keyup', function(e) {
            self.keyUp(e.keyCode);
        });
    };

    this.hide = function() {
        _div.removeClass('active');
        _pos = 0;
    };

    this.show = function(list) {
        _div.empty();
        for (var i = 0, len = list.length; i < len; i++) {
            var $row = jQuery('<div>' + list[i].keywordHigh + '</div>');
            $row.data('keyword', list[i].keyword);
            _div.append($row);
        }
        _div.addClass('active');
    };

    this.keyUp = function(keyCode) {
        if (keyCode === KEYBOARD.UP_ARROW) {
            this.nav(-1);
        }
        else if (keyCode === KEYBOARD.DOWN_ARROW) {
            this.nav(1);
        }
        else if (keyCode === KEYBOARD.ENTER) {
            if (_pos) {
                _div.find('div:nth-child(' + _pos + ')').click();
            } else {
                self.hide();
                if(_input.attr("id") == "geoportal-search-field"){
                    $("#geoportal-search-button").click();
                }else if(_input.attr("id") == "external-search-field"){
                    $("#external-search-button").click();
                }else{
                    prepareAndSearch();
                }
            }
        }
        else  if (keyCode !== KEYBOARD.LEFT_ARROW && keyCode !== KEYBOARD.RIGHT_ARROW) {
            var term = _input.val().trim();
            _search.setParam('terms', term);
            setTimeout(function() {
                if (_search.getParam('terms') === term && term.length >= _minLength) {
                    _search.autocomplete();
                    _search.setParam('terms', '');
                } else if (term.length <= 1) {
                    self.hide();
                }
            }, _search.timeoutDelay);
        }
    };

    this.onSelect = function(e) {
        var el = jQuery(e.target);
        var keyword = el.data('keyword') ? el.data('keyword') : el.parent().data('keyword');
        if (keyword) {
            _input.val(keyword);
            self.hide();
            search.setParam("terms", keyword);
            prepareAndSearch(true);
        }
    };

    this.nav = function(p) {
        var alldivs = _div.find('div');
        if (alldivs.length) {
            _pos = _pos + p;
            if (_pos < 1) {
                _pos = 0;
            } else if (_pos > alldivs.length) {
                _pos = alldivs.length;
            }
            var el = _div.find('div:nth-child(' + _pos + ')');
            _div.find('div').removeClass('active');
            el.addClass('active');
        }
    };

    this.init(search);
};

/**
 * Leaflet Map
 * @param $searchBbox
 * @param conf
 * @constructor
 */
function Map($searchBbox, conf) {
    var _map = null;
    var _$searchBbox = null;
    this.init = function(conf) {
        _$searchBbox = $searchBbox;
        _map = L.map(
            conf.mapId, {
                'center': new L.LatLng(conf.center.lat, conf.center.lon),
                'zoom': conf.zoom,
                'crs': L.CRS.EPSG4326
            }
        );
        L.tileLayer.wms(
            conf.wms.url, {
                'layers': conf.wms.layers,
                'format': conf.wms.format,
                'transparent': true
            }
        ).addTo(_map);
        _map.on('moveend', function() {
            _$searchBbox.val(_map.getBounds().toBBoxString());
        });
    };
    this.getBbox = function() {
        return _map.getBounds().toBBoxString();
    };
    this.init(conf);
}


/**
 * Group 1 = coming from download, shut down view
 * Group 2 = coming from view, shut down download
 */
function toggle_download_view_groups(id, group){
    switch(group){
        case(1):
            var group_elem = $('.resource-list.view_' + id);
            var btn = $('#view_' + id);
            break;
        case(2):
            var group_elem = $('.resource-list.download_' + id);
            var btn = $('#download_' + id);
            break;
        default:
            var group_elem = null;
            var btn = null;
    }
    if(group_elem.is(":visible")){
        group_elem.slideToggle("slow");
        btn.removeClass("active-button");
    }
}


/**
 * Set focus on search field
 */
function focus_on_search_input(){
     $(".simple-search-field").focus();
}

/**
 * Open the results after a search to lead the users attention
 */
function toggleSearchArea(){
    $("#search-area").click();
}
function toggleFilterArea(){
    $("#filter-area").click();
}

function openSpatialArea(){
    // blend in extra slow!
    $(".spatial-results-list").slideToggle("slow");
}

function openSpatialWrappers(){
    var wrappers = $(".spatial-search-result-wrapper");
    $.each(wrappers, function(i, wrapper){
        $(wrapper).slideToggle("slow");
    });
}

function disableSpatialCheckbox(){
    var checkbox = $("#spatial-checkbox");
    if (checkbox.is(":checked")){
        checkbox.click();
    }
}


/**
 * Switch the input field "off"
 */
function disableSearchInputField(){
    $(".simple-search-field").prop("disabled", true).css("opacity", 0.75);
    $(".search--submit").prop("disabled", true).css("opacity", 0.75);
    $("#spatial-checkbox").prop("disabled", true);
    $("#spatial-checkbox-wrapper").css("opacity", 0.75);
}

/**
 * Switch the input field "off"
 */
function enableSearchInputField(){
    $(".simple-search-field").prop("disabled", false).css("opacity", 1.0);
    $(".search--submit").prop("disabled", false).css("opacity", 1.0);
    $("#spatial-checkbox").prop("disabled", false);
    $("#spatial-checkbox-wrapper").css("opacity", 1.0);
}

function changeMapviewerIframeSrc(srcSuffix){
    // replace the src from "Geoportal-RLP" on
    var src = $("#mapviewer").attr("data-params");
    var srcArr = src.split("mb_user_myGui")
    var newSrc = srcArr[0] + "mb_user_myGui=" + srcSuffix;
    $("#mapviewer").attr("data-params", newSrc);
}

/*
 * Removes asterisks from search field so that the user won't has to see this implicit symbol
 */
function clearAsterisk(){
    var searchbar = $("#geoportal-search-field");
    searchbar.val(searchbar.val().replace("*", ""));
    search.setParam("terms", search.getParam("terms").replace("*",""));
}

/*
 * While a non-info search starts, a normal info search shall run in the background to provide infos for the current search term
 */
function startInfoCall(){
    var terms = search.getParam("terms");
    $.ajax({
        url: "/search/search/",
        headers: {
            "X-CSRFToken": getCookie("csrftoken")
        },
        data: {
            'source': "info",
            'type': 'results',
            'terms': terms
        },
        method: "post",
        format: "json",
        success: function(data){
            var numInfoResults = data["nresults"];
            var infoTabNumber = $("#info-result-number");
            infoTabNumber.text(numInfoResults);
            if(!infoTabNumber.is(":visible")){
                infoTabNumber.toggleClass("hide");
            }
        }
    })
}

function startAjaxMapviewerCall(value){
    $.ajax({
        url: "/map-viewer/",
        headers: {
            "X-CSRFToken": getCookie("csrftoken")
        },
        data: {
            'searchResultParam': value
        },
        type: 'get',
        dataType: 'json',
        success: function(data) {
            if(data["mapviewer_params"] != null){
                console.log(data["mapviewer_params"]);
                changeMapviewerIframeSrc(data["mapviewer_params"]);
                window.scrollTo(0,0);
                $(".map-viewer-toggler").click();
            }else if(data["url"] != null){
                var url = data["url"];
                window.open(url, "_blank").focus();
            }
        },
        error: function(jqXHR, textStatus, errorThrown){

        }
    });
}

/**
 * jQuery DOM Traversal and modify (controller/glue)
 *
 */
jQuery(document).ready(function() {

    var resources_rlp = {
        wms: true,
        wfs: true,
        wmc: true,
        dataset: true
    };
    var resources_de = {
        dataset: true,
        series: true,
        service: true,
        application: true,
        nonGeographicDataset: true,
    };

    var resources = resources_rlp;

    var fixDateFormat = function(val) {
        var ms = val.match(/(\d\d).(\d\d).(\d\d\d\d)/);
        if (ms) {
            return ms[3] + '-' + ms[2] + '-' + ms[1];
        }
        return null;
    };
    /*
    var fixDateFormats = function(items) {
        items.regTimeBegin = [fixDateFormat(items.regTimeBegin[0])];
        items.regTimeEnd = [fixDateFormat(items.regTimeEnd[0])];
        items.timeBegin = [fixDateFormat(items.timeBegin[0])];
        items.timeEnd = [fixDateFormat(items.timeEnd[0])];
    };
    */

     // set the focus on the search bar
     focus_on_search_input();


    function toggleResources(){
        if($(".-js-tab-item.active").attr("data-id") == "rlp"){
            resources = resources_rlp;
        }else{
            resources = resources_de;
        }
    }

    /**
     * Function that does the search
     * @param fromField
     */
    prepareAndSearch  = function(fromField, noPageReset) {
        if (search.searching){
            // if a search is already running - leave!
            return;
        }
        // remove '*' from search line, since it would not be necessary!
        clearAsterisk();
        // collapse map overlay if open
        var mapOverlay = $(".map-viewer-overlay");
        if(!mapOverlay.hasClass("closed")){
            $(".map-viewer-toggler").click();
        }
        toggleResources();
        var $current  = jQuery('.-js-content.active');
        var reslist = [];
        var keywords  = [];
        var terms     = [];
        var $farea    = $current.find('.-js-result .-js-filterarea');
        var allFacets = [];
        var isSpatialCheckboxSelected = $("#spatial-checkbox").is(":checked");

        // close search area so that loading bar will drop into viewport of user
        if($(".area-elements").is(":visible")){
            toggleSearchArea();
        }
        if($(".filterarea").is(":visible")){
            toggleFilterArea();
        }

        // disable input field during search
        disableSearchInputField();

        // set spatial checkbox info
        search.setParam("spatialSearch", isSpatialCheckboxSelected);

        // collect all already selected facets
        var facets = $(".-js-facet-item");
        $.each(facets, function(i, facet){
            var facetTitle = facet.innerText.trim();
            var facetId = $(facet).attr("data-id");
            var facetParent = $(facet).attr("data-parent");
            var facetData = [facetParent, facetTitle, facetId].join(",");
            allFacets.push(facetData);
        });
        // add new selected facet, if not yet selected
        if(allFacets.indexOf(search.getParam("facet")) === -1){
            allFacets.push(search.getParam("facet"));
        }
        // overwrite facet parameter
        search.setParam("facet", allFacets.join(";"));

        var prepareTerm = function(terms) {
           return terms.trim();
        };

        search.hide();

        var source = $(".content-tab-item.active").attr("data-id");
        search.setParam('source', source);
        var extended = $current.find('.-js-extended-search-form').serializeArray();
        var toEncode = {};
        $.each(extended, function(_, item) {
            if (toEncode[item.name]) {
                toEncode[item.name].push(item.value);
            } else {
                toEncode[item.name] = [item.value];
            }
        });
        //fixDateFormats(toEncode);

        var rs = [];
        $.each(resources, function(res, send) {
            if(send) {
                rs.push(res);
                reslist.push(res);
            }
        });

        extended = '&resolveCoupledResources=true&searchResources=' + rs.join(',');
        $.each(toEncode, function(key, values) {
            extended += '&' + key + '=' + values.join(',');
        });
        if (search.getParam('maxResults')) {
            extended += '&maxResults=' + search.getParam('maxResults');;
        }

        extended = encodeURIComponent(extended);
        search.setParam('extended', extended);
        if ($farea.length) {
            $farea.find('.-js-keyword').each(function() {
                keywords.push($(this).text().trim());
            });
            $farea.find('.-js-term').each(function() {
                var term = $(this).text();
                terms.push(prepareTerm(term.trim()));
            });
        }
        search.setParam('resources', JSON.stringify(reslist));
        var input = jQuery('.-js-simple-search-field');
        var fieldTerms = search.getParam("terms");
        var fieldTerms = prepareTerm(input.val());

        if (!noPageReset) {
            search.setParam('pages', 1);
        }
        search.find();
        jQuery('.-js-simple-search-autocomplete').removeClass('active');
        search.show();
    };


    /**
     * Start search if search button was clicked
     */
    // start search if search button clicked
    jQuery(document).on("click", '.-js-search-start', function() {
        var elem = $(this);
        var inputTerms = $(".-js-simple-search-field").val().trim();
        search.setParam("terms", inputTerms);
        // collapse extended search if open
        var extendedSearchHeader = $(".-js-extended-search-header");
        if(extendedSearchHeader.hasClass("active")){
            extendedSearchHeader.click();
        }
        prepareAndSearch(true); // search and render
    });

    /**
     *  Hide autocomplete form if body, outside was clicked
     */
    jQuery(document).on("click", 'body', function() {
        var $autocompleteSelect = jQuery('.-js-simple-search-autocomplete');

        if( $autocompleteSelect.hasClass('active') === true) {
            $autocompleteSelect.removeClass('active');
        }
    });

    /**
     *  Hide download options for search results
     */
    $(document).on("click", '.download-button', function(){
        var btn_id = $(this).attr('id');
        var id_raw = btn_id.split("_")[1];
        var btn = $(this)
        var group = $(".resource-list." + btn_id);
        if (group.is(":visible")){
            group.slideToggle("slow");
            btn.removeClass("active-button");
        }else{
            toggle_download_view_groups(id_raw, 1);
            group.slideToggle("slow");
            btn.addClass("active-button");
        }

    });

    $(document).on('click', '.keywords--headline', function(){
        $('.keywords--headline .accordion').toggleClass('closed').toggleClass('open');
    });

    $(document).on('click', '.sublayer-more', function(){
        var acc = $(this).find('.accordion');
        acc.toggleClass('closed').toggleClass('open');
        if(acc.hasClass('closed')){
            acc.attr('title', "Ausklappen");
        }else{
            acc.attr('title', "Einklappen");
        }
    });

    /**
     *  Hide view options for search results
     */
    $(document).on("click", '.view-button', function(){
        var btn_id = $(this).attr('id');
        var id_raw = btn_id.split("_")[1];
        var btn = $(this)
        var group = $(".resource-list." + btn_id);
        if (group.is(":visible")){
            group.slideToggle("slow");
            btn.removeClass("active-button");
        }else{
            toggle_download_view_groups(id_raw, 2);
            group.slideToggle("slow");
            btn.addClass("active-button");
        }
    });

    /**
     * Handle deselection of spatial restriction items
     */
     $(document).on("click", ".-js-spatial-restriction", function(){
        var elem = $(this);
        // deselect spatial search field
        var checkbox = $("#spatial-checkbox");
        checkbox.attr("checked", false);
        // now remove spatial restriction and start a new search
        elem.remove();
        prepareAndSearch();

     });

    /**
     * Handle facet selection
     */
     $(document).on("click", ".-js-subfacet", function(){
        var elem = $(this);
        var facetKeyword = elem.attr("data-name").trim();
        var facetId = elem.attr("data-id");
        var facetParent = elem.attr("data-parent").trim();
        var facetData = [facetParent, facetKeyword, facetId].join(",");
        search.setParam("facet", facetData);
        prepareAndSearch();
     });

     /**
     * Handle facet removing
     */
     $(document).on("click", ".-js-facet-item", function(){
        $(this).remove();
        prepareAndSearch();
     });

     /**
      * Handle area title accordion
      */
      $(document).on("click", ".area-title", function(){
        var elem = $(this);
        elem.parent().find(".area-elements").slideToggle("slow");
      });

      /**
      * Handle spatial search result clicking
      */
      $(document).on("click", ".spatial-search-result", function(){
        var elem = $(this);
        var bboxParams = elem.attr("data-params");
        var termsParams = elem.attr("data-source");
        var locationParam = elem.attr("data-target");
        // remove locationParam from searchfield input!
        var searchField = $("#geoportal-search-field");
        var checkbox = $("#spatial-checkbox");
        checkbox.attr("checked", false);
        searchField.val(searchField.val().replace(locationParam, "").trim());
        search.setParam("terms", termsParams);
        search.setParam("searchBbox", bboxParams);
        search.setParam("searchTypeBbox", "intersects");
        prepareAndSearch();
      });


    $(document).on("mouseover", ".resource-element-info-logging", function(){
        var elem = $(this);
        elem.attr("src", "/static/searchCatalogue/images/icons/icn_isLogging_hover.png");
    });
    $(document).on("mouseout", ".resource-element-info-logging", function(){
        var elem = $(this);
        elem.attr("src", "/static/searchCatalogue/images/icons/icn_isLogging.png");
    });

    $(document).on("mouseover", ".resource-element-info-network", function(){
        var elem = $(this);
        elem.attr("src", "/static/searchCatalogue/images/icons/icn_isNetworkRestricted_hover.png");
    });
    $(document).on("mouseout", ".resource-element-info-network", function(){
        var elem = $(this);
        elem.attr("src", "/static/searchCatalogue/images/icons/icn_isNetworkRestricted.png");
    });

    $(document).on("mouseover", ".resource-element-info-price", function(){
        var elem = $(this);
        elem.attr("src", "/static/searchCatalogue/images/icons/icn_price_hover.png");
    });
    $(document).on("mouseout", ".resource-element-info-price", function(){
        var elem = $(this);
        elem.attr("src", "/static/searchCatalogue/images/icons/icn_price.png");
    });

    $(document).on("mouseover", ".resource-element-info-queryable", function(){
        var elem = $(this);
        elem.attr("src", "/static/searchCatalogue/images/icons/icn_queryable_hover.png");
    });
    $(document).on("mouseout", ".resource-element-info-queryable", function(){
        var elem = $(this);
        elem.attr("src", "/static/searchCatalogue/images/icons/icn_queryable.png");
    });

    $(document).on("mouseover", ".not-allowed-img", function(){
        var elem = $(this);
        elem.attr("src", "/static/searchCatalogue/images/icons/icn_permission_restricted_hover.png");
    });
    $(document).on("mouseout", ".not-allowed-img", function(){
        var elem = $(this);
        elem.attr("src", "/static/searchCatalogue/images/icons/icn_permission_restricted.png");
    });

    $(document).on("mouseover", ".ask-permission-img", function(){
        var elem = $(this);
        elem.attr("src", "/static/searchCatalogue/images/icons/icn_permission_email_hover.png");
    });
    $(document).on("mouseout", ".ask-permission-img", function(){
        var elem = $(this);
        elem.attr("src", "/static/searchCatalogue/images/icons/icn_permission_email.png");
    });



    $(document).on("mouseover", "#filter-area", function(){
        var elem = $(this);
        var elem_img = elem.find("img");
        elem_img.attr("src", "/static/searchCatalogue/images/icons/icn_filter_hover.png");
    });
    $(document).on("mouseout", "#filter-area", function(){
        var elem = $(this);
        var elem_img = elem.find("img");
        elem_img.attr("src", "/static/searchCatalogue/images/icons/icn_filter.png");
    });

    $(document).on("mouseover", "#add-map-button-div", function(){
        var elem = $(this);
        var elem_img = elem.find("img");
        elem_img.attr("src", "/static/searchCatalogue/images/icons/icn_map_2018_hover.png");
    });
    $(document).on("mouseout", "#add-map-button-div", function(){
        var elem = $(this);
        var elem_img = elem.find("img");
        elem_img.attr("src", "/static/searchCatalogue/images/icons/icn_map_2018.png");
    });

    $(document).on("mouseover", "#add-map-and-zoom-button-div", function(){
        var elem = $(this);
        var elem_img = elem.find("img");
        elem_img.attr("src", "/static/searchCatalogue/images/icons/icn_zoommap_2018_hover.png");
    });
    $(document).on("mouseout", "#add-map-and-zoom-button-div", function(){
        var elem = $(this);
        var elem_img = elem.find("img");
        elem_img.attr("src", "/static/searchCatalogue/images/icons/icn_zoommap_2018.png");
    });

    $(document).on("mouseover", "#capabilities-button-div", function(){
        var elem = $(this);
        var elem_img = elem.find("img");
        elem_img.attr("src", "/static/searchCatalogue/images/icons/icn_capabilities_2018_hover.png");
    });

    $(document).on("mouseout", "#capabilities-button-div", function(){
        var elem = $(this);
        var elem_img = elem.find("img");
        elem_img.attr("src", "/static/searchCatalogue/images/icons/icn_capabilities_2018.png");
    });

    $(document).on("mouseover", ".feed-download", function(){
        var elem = $(this);
        var elem_img = elem.find(".feed-download-img");
        elem_img.attr("src", "/static/searchCatalogue/images/icons/icn_download_2018_hover.png");
    });

    $(document).on("mouseout", ".feed-download", function(){
        var elem = $(this);
        var elem_img = elem.find(".feed-download-img");
        elem_img.attr("src", "/static/searchCatalogue/images/icons/icn_download_2018.png");
    });

    $(document).on("click", ".thumbnail-extent", function(){
        var elem = $(this);
        var url = elem.attr("src");
        // set higher resolution for image in link
        url = url.split("&");
        $.each(url, function(i, param){
            if(param.includes("WIDTH")){
                url[i] = "WIDTH=600";
            }else if (param.includes("HEIGHT")){
                url[i] = "HEIGHT=600";
            }
        });
        url = url.join("&");
        openInNewTab(url);
    });

    $(document).on("click", ".thumbnail-preview", function(){
        var elem = $(this);
        var url = elem.attr("src");
        openInNewTab(url);
    });

    $(document).on("click", ".ask-permission-img", function(){
        var elem = $(this);
        var params = {
            "dataProvider": elem.attr("data-params"),
            "layerId": elem.attr("data-id"),
            "layerName": elem.attr("data-name")
        }
        $.ajax({
            url: "/search/permission-email/",
            headers: {
                "X-CSRFToken": getCookie("csrftoken")
            },
            data: params,
            success: function(data){
                var html = data["html"];
                var searchOverlay = $("#overlay");
                var searchOverlayContent = $(".search-overlay-content");
                searchOverlay.toggleClass('gray-out-overlay');
                searchOverlayContent.html(html);
                searchOverlayContent.toggle("slow");
                searchOverlayContent.toggleClass("flex");
            }
        });
    });


    /*
        Close the email form
    */
    $(document).on("click", "#cancel-permission-email-button, #send-permission-email-button", function(){
        var elem = $(this);
        var elemId = elem.attr("id");
        var searchOverlay = $("#overlay");
        var searchOverlayContent = $(".search-overlay-content");
        var params = {
            "address": $(".email-to-label-address").text().trim(),
            "subject": $(".email-subject-content").text().trim(),
            "message": $(".email-input-field").val()
        }
        if(elemId == "send-permission-email-button"){
            $.ajax({
                url: "/search/send-permission-email",
                data: params,
                success: function(data){
                    // ToDo: Inform the user about fail or succes!
                }
            });
        }
        searchOverlayContent.toggle("slow");
        searchOverlay.toggleClass('gray-out-overlay');

    });

    /*
     * Spatial search title event listener (opens all spatial search results for a location)
     */
     $(document).on("click", ".spatial-result-title", function(){
        var elem = $(this);
        elem.next(".spatial-search-result-wrapper").slideToggle("slow");
     });

    /*
     * Changes the language
     */
    $(document).on("click", ".flag-selector", function(){
        var elem = $(this);
        // do nothing if clicked language is active language
        if(elem.hasClass("active-language")){
            return;
        }
        var value = elem.attr("data-id");
        var otherFlag = elem.siblings().first();
        // de-/activate other language visibly
        elem.toggleClass("active-language");
        otherFlag.toggleClass("active-language");
        // activate selected language via ajax call
        $.ajax({
            url: "/i18n/setlang/",
            headers: {
                "X-CSRFToken": getCookie("csrftoken")
            },
            data: {
                'language': value
            },
            type: 'post',
            dataType: 'json',
            success: function(data) {
                location.reload();
            },
            timeout: 60000,
            error: function(jqXHR, textStatus, errorThrown){
                if(textStatus === "timeout"){
                    alert("A timeout occured.");
                }
                /*else{
                    alert(errorThrown);
                }
                */
            }
        })
    });

    /*
     * Terms of use event listener
     */
    $(document).on("click", "#add-map-button, #add-map-and-zoom-button", function(event){
        var elem = $(this);
        var elem_href = elem.attr("href");
        var tou = elem.siblings("#terms-of-use");
        event.preventDefault();
        if(tou.length == 0){
            startAjaxMapviewerCall(elem_href);
        }else{
            var acceptButton = tou.find("#tou_button_accept");
            tou.toggleClass("open");
            acceptButton.attr("data-params", elem_href);
        }
    });

    $(document).on("click", "#tou-close, #tou_button_decline", function(){
        var elem = $(this);
        var tou = elem.parents("#terms-of-use");
        tou.toggleClass("open");
    });
    /*
    $(document).on("click", "#tou_button_decline", function(){
        var elem = $(this);
        var tou = elem.parents("#terms-of-use");
        tou.toggleClass("open");
    });
    */
    $(document).on("click", "#tou_button_accept", function(event){
        event.preventDefault();
        var elem = $(this);
        var tou = elem.parents("#terms-of-use");
        var value = elem.attr("data-params");
        tou.toggleClass("open");
        // start ajax call to server to decide what to do
        // for search/external a new browser tab shall open, leading to geoportal/map-viewer
        // for search/ the geoportal mapviewer iframe shall be changed in the way it displays the new selected data
        startAjaxMapviewerCall(value);
    });



    /**
     * Open and clode form of the extended search
     * @extendedSearch
     */
    jQuery(document).on('click', '.-js-extended-search-header', function() {
        $('.-js-extended-search-header .accordion').toggleClass('closed').toggleClass('open');
        var $this = jQuery(this);
        var $parent = $this.parent().find('.-js-search-extended');
        $this.toggleClass("active");
        $parent.slideToggle("slow");
        $parent.toggleClass("active");
    });

    $(document).on('click', '.-js-show-facets', function() {
        $('.-js-show-facets .accordion').toggleClass('closed').toggleClass('open');
        if ($('.-js-show-facets .accordion').hasClass('open')) {
            $('.-js-facets').slideToggle("slow");
        } else {
            $('.-js-facets').slideToggle("slow");
        }
    });

    /**
     * Navigates through tabs in extended search form
     * @extendedSearch
     */
    jQuery(document).on("click", ".search-tabs > .-js-tab-item", function() {
        var newTab = jQuery(this);
        var oldTab = newTab.parent().find('> .-js-tab-item.active');   // find old tab
        if(oldTab.attr('data-id') === newTab.attr('data-id')){
            return;
        }
        oldTab.removeClass('active');                           // set old tab inactive
        var oldTabContent = $("#" + oldTab.attr('data-id'));    // get old tab content
        oldTabContent.slideToggle("slow");                           // let old content disappear
        oldTabContent.toggleClass("hide");
        newTab.addClass('active');                              // set new tab active
        var newTabContent = $('#' + newTab.attr('data-id'));    // get new tab content
        newTabContent.slideToggle("slow");                           // let new content appear
        newTabContent.toggleClass("hide");
    });

    /**
     * Navigate through tabs in content selection header
     */
     $(document).on("click", ".content-tabs > .-js-tab-item", function(){
        var newTab = $(this);                                           // get new tab
        var oldTab = newTab.parent().find("> .-js-tab-item.active");    // get old tab
        oldTab.toggleClass("active");                                   // set inactive
        oldTab.find("img").toggleClass("active-img");
        newTab.toggleClass("active");                                   // set active
        newTab.find("img").toggleClass("active-img");
        search.setParam("source", newTab.attr("data-id"));
        // make sure to drop the spatial search if it is still enabled
        disableSpatialCheckbox();
        // run search as always
        $("#geoportal-search-button").click();

     });

     $(document).on("click", ".filter-onlyOpenData-img", function(){
        var elem = $(this);
        if(elem.hasClass("active-img")){
            search.setParam("onlyOpenData", false);
        }else{
            search.setParam("onlyOpenData", true);
        }
        elem.toggleClass("active-img");
        prepareAndSearch();
     });

    /**
     * Resets selectioned themes in extended search
     * @extendedSearch
     */
    jQuery(document).on("click", ".-js-reset-select", function() {
        var target = '#' + jQuery(this).attr('data-target');
        jQuery(target).prop('selectedIndex', -1); //set select to no selection
    });

    /**
     * Show and hide map in extended search form
     * @extendedSearch
     */
    jQuery(document).on("click", '[name="searchBbox"]', function() {

        if (!mapConf) {
            return;
        }

        var $this = jQuery(this);
        var $form = $this.parents('form:first');
        var search = $form.attr('data-search');

        if ($this.prop('checked')) {
            $form.find('div.map-wrapper').append(jQuery('<div id="' + search + '-map" class="map"></div>'));
            maps[search] = new Map($this, mapConf[search]);
            $this.val(maps[search].getBbox());
            jQuery('#' + search + '-searchTypeBbox-intersects').click();
        }
        else {
            $form.find('#' + search + '-map').remove();
            delete(maps[search]);
            $this.val('');
        }
    });

    /**
     * Applies datepicker functionality for every date input field in
     * @extendedSearch
     */
    jQuery('input.-js-datepicker').each(function() {
        $(this).Zebra_DatePicker({
            show_icon: true,
            offset:[-177,120],
            format: 'd-m-Y',
            lang_clear_date:'Datum löschen',
            show_select_today:"Heute",
            days_abbr:['So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa'],
            months:['Januar', 'Februar', 'März', 'April','Mai', 'Juni', 'Juli', 'August','September','Oktober','November','Dezember']
        });
    });


    //show and hide keywords / schlagwortsuche in results
    jQuery(document).on('click', '.keywords--headline', function(e) {
        e.preventDefault();

        var $this = $(this);
        var $container = $this.parent().find('.keywords--container');

        if( $container.hasClass('hide') ) {
            $container.slideToggle("slow");
            $container.removeClass('hide');
        }
        else {
            $container.slideToggle("slow");
            $container.addClass('hide');
        }
    });

    $(document).on('click', '.sublayer-more', function(){
        var sublayer = $(this).parent().children('.result-item-layer');
        $(this).toggleClass('active-button');
        sublayer.slideToggle("slow");
        sublayer.toggleClass('hide');

    });

    // pagination handler for getting to next or previous page
    jQuery(document).on('click', '.pager .-js-pager-item', function() {
        search.setParam('data-id', jQuery(this).parent().attr('data-id'));
        search.setParam('pages', jQuery(this).attr('data-page'));
        search.setParam('previousPage', search.getParam('pages', 1)); //alternativly we can use .-js-pager-item .active
        search.setParam('paginated', true);
        search.setParam('terms', $(".-js-simple-search-field").val());
        prepareAndSearch(undefined, true);
    });

    jQuery(document).on("click", ".-js-keyword", function() {
        var $self = jQuery(this);
        var keyword = $self.text().trim();
        var searchInput = $(".simple-search-field");
        searchInput.val(searchInput.val() + " " + keyword);
        search.setParam("terms", keyword);
        prepareAndSearch();
    });

    $(document).on('change', '#geoportal-search-extended-what input', function() {
        var v = $(this).val();
        resources[v] = $(this).is(':checked');
        $('[data-resource=' + v + ']').click();
    });

    /*
     * Event listener for language changing
    $(document).on("change", "#lang-code", function(){
        var value = $(this).val();
        jQuery.ajax({
            url: "/i18n/setlang/",
            headers: {
                "X-CSRFToken": getCookie("csrftoken")
            },
            data: {
                'language': value
            },
            type: 'post',
            dataType: 'json',
            success: function(data) {
                //location.reload();
            },
            timeout: 60000,
            error: function(jqXHR, textStatus, errorThrown){
                if(textStatus === "timeout"){
                    alert("A timeout occured.");
                }else{
                    alert(errorThrown);
                    console.log(errorThrown);
                }
            }
        })
    });
     */

    /**
     * Activates, deactivates resources
     */
    jQuery(document).on("click", ".-js-filterarea .-js-resource", function() {
        // check that the correct resources are globally available
        toggleResources();

        var $self = jQuery(this);

        $self.toggleClass("inactive");

        var v = $self.data('resource');
        var active = !$self.hasClass('inactive');
        resources[v] = active;
        v = v.charAt(0).toUpperCase() + v.slice(1);
        $('#geoportal-checkResources' + v).prop('checked', active);

        prepareAndSearch();
    });

    /**
     * Show or hide subfacets
     */
    $(document).on("click", ".-js-subfacet-toggle-button", function(){
        var elem = $(this);
        var restDiv = elem.siblings(".subfacets-rest");
        restDiv.slideToggle("slow");

    });

    jQuery(document).on("click", ".-js-term", function() {
        var $this = jQuery(this);
        var text = $this.text().trim();

        // remove search word from input field
        var searchField = $(".simple-search-field");
        var searchText = searchField.val().trim();
        var searchTextArr = searchText.split(" ");
        var searchTextArrNew = []
        $.each(searchTextArr, function(i, elem){
            if (elem.trim() != text){
                searchTextArrNew.push(elem);
            }
        });
        var searchTextNew = searchTextArrNew.join(" ");

        // remove search word from search.keyword
        if (search.keyword == text){
            search.keyword = null;
        }

        // remove search word from search parameter
        var searchParam = search.getParam("terms");
        var searchTextArr = searchParam.split(" ");
        var searchTextArrNew = []
        $.each(searchTextArr, function(i, elem){
            if (elem.trim() != text){
                searchTextArrNew.push(elem);
            }
        });
        var searchTextNew = searchTextArrNew.join(" ");
        search.setParam("terms", searchTextNew);
        searchField.val(searchTextNew);

        $this.remove();
        prepareAndSearch();
    });

    $(document).on("click", ".info-search-result", function(){
        var elem = $(this);
        var wikiKeyword = elem.attr("data-target");
        // start call for mediawiki content
        $.ajax({
            url: "/" + wikiKeyword,
            headers: {
                "X-CSRFToken": getCookie("csrftoken")
            },
            data: {
                "info_search": true,
                "category": ""
            },
            success: function(data){
                var con = data["content"];
                var article = $(".mediawiki-article");
                if(article.is(":visible")){
                    article.toggle();
                }
                article.html(con);
                article.slideToggle("slow");
                // collapse all search results
                var wrapper = $(".source--title.-js-title").click();
            }
        })
    });

    /**
     * Show and Hide (toggle) results in resources/categories e.g. dataset, services, modules, mapsummary
     */
    jQuery(document).on("click", '.search-header .-js-title', function(e) {
        var $this = jQuery(this);
        var thisBody = $this.parents(".search-cat").find(".search--body");
        thisBody.toggle("slow");
        thisBody.toggleClass("hide");
    });

    $(document).on('change', '#geoportal-maxResults', function() {
        search.setParam('maxResults', $(this).val());
        prepareAndSearch();
    });

    $(document).on('change', '#geoportal-orderBy', function() {
        var opt = $("#geoportal-orderBy :selected");
        var uri = opt.attr("data-url");
        var uriArr = uri.split("&");
        $.each(uriArr, function(i, param){
            if(param.includes("orderBy")){
                search.setParam('orderBy', param.split("=")[1]);
            }
        });
        prepareAndSearch(undefined, true);
    });
    
    search.setParam('source', jQuery('.-js-content-tab-item.active').attr('data-source'));
    autocomplete = new Autocomplete(search);

    // Avoid `console` errors in browsers that lack a console.
    (function() {
        var method;
        var methods = [
            'assert', 'clear', 'count', 'debug', 'dir', 'dirxml', 'error',
            'exception', 'group', 'groupCollapsed', 'groupEnd', 'info', 'log',
            'markTimeline', 'profile', 'profileEnd', 'table', 'time', 'timeEnd',
            'timeStamp', 'trace', 'warn'
        ];
        var length = methods.length;
        var console = (window.console = window.console || {});

        while (length--) {
            method = methods[length];

            // Only stub undefined methods.
            if (!console[method]) {
                console[method] = $.noop;
            }
        }
    }());
});