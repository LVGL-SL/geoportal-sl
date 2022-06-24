"""

Author: Michel Peltriaux
Organization: Spatial data infrastructure Rheinland-Pfalz, Germany
Contact: michel.peltriaux@vermkv.rlp.de
Created on: 22.01.19

"""
import logging
import smtplib
import time

from django.core.mail import send_mail
from django.http import HttpRequest
from django.shortcuts import render
from django.template.loader import render_to_string
from django.utils.translation import gettext as _
from django_extensions import settings

from Geoportal.decorator import check_browser
from Geoportal.geoportalObjects import GeoportalJsonResponse, GeoportalContext
from Geoportal.settings import DE_CATALOGUE, EU_CATALOGUE, PRIMARY_CATALOGUE, OPEN_DATA_URL, HOSTNAME, HTTP_OR_SSL, SESSION_NAME
from Geoportal.utils.php_session_data import get_mb_user_session_data
from Geoportal.utils.utils import print_debug
from searchCatalogue.utils import viewHelper, spatial_filter_helper
from searchCatalogue.utils.autoCompleter import AutoCompleter
from searchCatalogue.utils.rehasher import Rehasher
from searchCatalogue.utils.searcher import Searcher
from searchCatalogue.utils.viewHelper import check_search_bbox
from searchCatalogue.settings import DEFAULT_MAX_SEARCH_RESULTS
from useroperations.models import MbUser
from Geoportal.utils import utils

EXEC_TIME_PRINT = "Exec time for %s: %1.5fs"

app_name = ""

logger = logging.getLogger(__name__)


@check_browser
def index_external(request: HttpRequest):
    """ Renders the index template for external embedded calls.

    This route is for external embedded calls in iFrames and so on.
    The template provides an own searchbar, which is not necessary on the geoportal homepage.

    Args:
        request (HttpRequest): The incoming request
    Returns:
        Redirect: Redirect to the real render functionality with a flag for external_call
    """
    external_call = True
    params_get = request.GET
    start_search = utils.resolve_boolean_value(params_get.get("start", "False"))

    return index(request=request, external_call=external_call, start_search=start_search)


@check_browser
def index(request: HttpRequest, external_call=False, start_search=False):
    """ Renders the index template for all calls.

    If the external_call flag is set to True, this function will change the template to be rendered.

    Args:
        request (HttpRequest): The incoming request
        external_call: A flag that indicates if the call comes from an external source
    Returns:
        The rendered page
    """
    template_name = "index.html"
    get_params = request.GET.dict()
    searcher = Searcher()
    facets = searcher.search_categories_list(lang=request.LANGUAGE_CODE)
    preselected_facets = viewHelper.get_preselected_facets(get_params, facets)

    # renaming facet variables for dynamical reasons!
    for key, value in preselected_facets.items():
        key_trans = _(key)
        del preselected_facets[key]
        for v in value:
            v["parent_category"] = _(v["parent_category"])
        preselected_facets[key_trans] = value

    sources = viewHelper.get_source_catalogues(external_call)

    params = {
        "title": _("Search"),
        "basedir": settings.BASE_DIR,
        "sources": sources,
        "value_form_map": "",
        "value_form": "",
        "value_form_map_as_json": "",
        "selected_facets": preselected_facets,
        "external_call": external_call,
        "start_search": start_search,
    }
    geoportal_context = GeoportalContext(request=request)
    geoportal_context.add_context(params)

    if external_call:
        geoportal_context.add_context(context={"extended_template": "none.html"})
    else:
        geoportal_context.add_context(context={"extended_template": "base.html"})

    return render(request, template_name, geoportal_context.get_context())


@check_browser
def auto_completion(request: HttpRequest):
    """ Returns suggestions for searchfield input

    The call comes from an ajax function, therefore we respond using a JsonResponse,
    which can be parsed by ajax.

    Args:
        request (HttpRequest): The incoming request
    Returns:
        JsonResponse: Contains auto-completion suggestions
    """
    max_results = 5

    if request.method == "GET":
        content = request.GET.dict()
    elif request.method == "POST":
        content = request.POST.dict()
    else:
        # nothing else is supported
        return GeoportalJsonResponse().get_response()

    search_text = content["terms"]

    # clean for UMLAUTE!
    search_text = search_text.replace("ö", "oe")
    search_text = search_text.replace("Ö", "Oe")
    search_text = search_text.replace("ä", "ae")
    search_text = search_text.replace("Ä", "Ae")
    search_text = search_text.replace("ü", "ue")
    search_text = search_text.replace("U", "Ue")
    search_text = search_text.replace("ß", "ss")

    auto_completer = AutoCompleter(search_text, max_results)

    # Fetch data
    data_search_suggestions = auto_completer.get_data_search_suggestions()
    location_search_suggestions = auto_completer.get_location_suggestions()

    # Prepare data for rendering
    tmp = []
    for loc in location_search_suggestions:
        tmp += loc.get("geonames", [])
    location_search_suggestions = tmp
    data_search_suggestions = data_search_suggestions.get("resultList", [])

    # Strange behaviour can be occured on the API when fetching 'Kob' and 'Kobl'. One time a list is returned,
    # another time a dict. Since we need a list here, we need to fix this for now by ourselves.
    tmp = []
    if isinstance(data_search_suggestions, dict):
        for k, v in data_search_suggestions.items():
            tmp.append(v)
        data_search_suggestions = tmp

    params = {
        "data_suggestions": data_search_suggestions,
        "location_suggestions": location_search_suggestions,
    }
    html = render_to_string("autocompleter/suggestions.html", context=params, request=request)

    return GeoportalJsonResponse(html=html).get_response()


def resolve_coupled_resources(request: HttpRequest):
    """ Find coupled resources for DE/EU catalogue search results

    Args:
        request: The incoming request
        uri: The metadata link
    Returns:
         An ajax response
    """
    GET_params = request.GET.dict()
    uri = GET_params.get("mdLink", "")
    template = "other/coupled_resources.html"
    coupled_resources = viewHelper.resolve_coupled_resources(uri)
    params = {
        "coupled_resources": coupled_resources,
        "type": "service_DE",
    }
    html = render_to_string(template, params, request)
    return GeoportalJsonResponse(html=html, data=params).get_response()


@check_browser
def get_data(request: HttpRequest):
    """ Redistributor for general get_data requests.

    Decides which kind of data needs to be fetched and redirects to the according view.

    Args:
        request (HttpRequest): The incoming request
    Returns:
        JsonResponse: If nothing was found, an empty JsonResponse will be returned to reduce the harm
        Redirects otherwise to working functions.
    """
    if not request.is_ajax():
        return GeoportalJsonResponse().get_response()

    post_params = request.POST.dict()
    # Check if spatial search is required
    spatial = post_params.get("spatial", "") == "true"
    search_box = post_params.get("searchBbox", "")
    if spatial is not None:
        if spatial:
            # spatial is selected but there are no search_bbox parameters yet -> A spatial search result was not selected yet -> Show them!
            return get_spatial_results(request)

    # Check which source is requested
    source = post_params.get("source", None)
    if source is not None:
        if source == "primary":
            # call primary search method
            return get_data_primary(request)
        elif source == "de":
            # call other search method
            return get_data_other(request, catalogue_id=DE_CATALOGUE)
        elif source == "eu":
            # call other search method
            return get_data_other(request, catalogue_id=EU_CATALOGUE)
        elif source == "info":
            # call info search method
            return get_data_info(request)
        else:
            return GeoportalJsonResponse().get_response()
    else:
        return GeoportalJsonResponse().get_response()


@check_browser
def get_spatial_results(request: HttpRequest):
    """ Returns the data for a spatial search.

    Args:
        request (HttpRequest): The incoming request
    Returns:
        JsonResponse: Contains the content for the ajax call
    """
    template = app_name + "spatial/spatial_search_results.html"
    post_params = request.POST.dict()
    search_text = post_params.get("terms")

    # Check if a shortcut based filter input has to be processed
    if spatial_filter_helper.uses_shortcut(search_text):
        results = spatial_filter_helper.process_shortcut_filter(search_text)
    else:
        results = spatial_filter_helper.process_regular_filter(search_text)

    view_content = render_to_string(template, results)

    return GeoportalJsonResponse(html=view_content).get_response()


@check_browser
def get_data_other(request: HttpRequest, catalogue_id):
    """ Returns data for other search catalogues than the primary.

    Args:
        request (HttpRequest): The incoming request
        catalogue_id: Specifies which catalogue (API) shall be used
    Returns:
        JsonResponse: Contains the content for the ajax call
    """
    post_params = request.POST.dict()
    template_name = app_name + "search_results.html"

    # extract parameters
    start_time = time.time()
    search_words = post_params.get("terms")
    is_eu_search = False
    is_de_search = True

    search_pages = int(post_params.get("page-geoportal"))
    requested_page_res = post_params.get("data-geoportal")
    requested_resources = viewHelper.prepare_requested_resources(post_params.get("resources"))

    # prepare bbox parameter
    search_bbox = post_params.get("searchBbox", "")
    search_type_bbox = post_params.get("searchTypeBbox", "")

    source = post_params.get("source", "")
    if source == 'eu':
        is_eu_search = True
        is_de_search = False
        all_resources = {
            "dataset": _("Datasets"),
            "series": _("Series"),
            "service": _("Services"),
        }
    else:
        all_resources = {
            "dataset": _("Datasets"),
            "series": _("Series"),
            "service": _("Services"),
            "application": _("Applications"),
            "nonGeographicDataset": _("Miscellaneous Datasets"),
        }

    print_debug(EXEC_TIME_PRINT % ("extracting parameters", time.time() - start_time))

    # run search DE
    searcher = Searcher(page_res=requested_page_res,
                        keywords=search_words,
                        page=search_pages,
                        bbox=search_bbox,
                        type_bbox=search_type_bbox,
                        resource_set=requested_resources,
                        language_code=request.LANGUAGE_CODE,
                        catalogue_id=catalogue_id,
			            host=HOSTNAME,
                        )
    start_time = time.time()
    search_results = searcher.search_external_catalogue_data()
    print_debug(EXEC_TIME_PRINT % ("total search in catalogue with ID " + str(catalogue_id), time.time() - start_time))

    # prepare search filters
    # search_filters = viewHelper.get_search_filters(search_results)

    # rehasher = Rehasher(search_results, search_filters)
    # search_filters = rehasher.get_rehashed_filters()

    # split used searchFilters from searchResults
    search_filters = {}
    for resource_key, resource_val in search_results.items():
        if len(search_filters) == 0:
            search_filters = resource_val["searchFilter"]

    start_time = time.time()
    # prepare pages to render for all resources
    pages = viewHelper.calculate_pages_to_render_de(search_results, search_pages, requested_page_res)
    print_debug(EXEC_TIME_PRINT % ("calculating pages to render", time.time() - start_time))

    # ONLY FOR EU
    if is_eu_search:
        start_time = time.time()
        # hash inspire id, so we can use them in a better way with javascript
        search_results = viewHelper.hash_inspire_ids(search_results)
        print_debug(EXEC_TIME_PRINT % ("hash inspire ids", time.time() - start_time))

    start_time = time.time()
    # prepare preview images
    search_results = viewHelper.check_previewUrls(search_results)
    print_debug(EXEC_TIME_PRINT % ("checking previewUrls", time.time() - start_time))

    # check for bounding box
    bbox = post_params.get("searchBbox", '')
    session_id = request.COOKIES.get(SESSION_NAME, "")
    check_search_bbox(session_id, bbox)

    results = {
        "source": source,
        "search_results": search_results,
        "search_filters": search_filters,
        "is_de_search": is_de_search,
        "is_eu_search": is_eu_search,
        "resources": requested_resources,
        "pages": pages,
        "all_resources": all_resources,
        "OPEN_DATA_URL": OPEN_DATA_URL,
        "sources": viewHelper.get_source_catalogues(False)
    }
    # since we need to return plain text to the ajax handler, we need to use render_to_string
    start_time = time.time()
    view_content = render_to_string(template_name, results)
    print_debug(EXEC_TIME_PRINT % ("rendering view", time.time() - start_time))

    return GeoportalJsonResponse(html=view_content, params={}).get_response()


@check_browser
def get_data_primary(request: HttpRequest):
    """ Returns data for the primary search catalogue

    Args:
        request (HttpRequest): The incoming request
    Returns:
        JsonResponse: Contains data for the ajax call
    """
    post_params = request.POST.dict()
    template_name = app_name + "search_results.html"
    resources = {
        "dataset": _("Datasets"),
        "wms": _("Web Map Services"),
        "wfs": _("Search-, Download-,Gathering-modules"),
        "wmc": _("Map Combinations"),
        "application": _("Applications"),
    }
    lang_code = request.LANGUAGE_CODE

    # get user php session info
    session_data = get_mb_user_session_data(request)

    # prepare bbox parameter
    search_bbox = post_params.get("searchBbox", "")
    search_type_bbox = post_params.get("searchTypeBbox", "")

    # prepare order parameter
    order_by = post_params.get("orderBy")


    # prepare rpp parameter
    max_results = post_params.get("maxResults", 5)
    if max_results == "":
        max_results = DEFAULT_MAX_SEARCH_RESULTS
    elif isinstance(max_results, str):
        max_results = int(max_results)

    if max_results == False:
        max_results = 5

    # prepare selected facets for rendering
    selected_facets = post_params.get("facet").split(";")

    # prepare extended search parameters
    extended_search_params = viewHelper.parse_extended_params(post_params)
    selected_facets = viewHelper.prepare_selected_facets(selected_facets)

    # prepare search tags (keywords)
    keywords = post_params["terms"].split(",")

    # prepare requeste resources to be an array of strings
    # requested_resources: str
    requested_resources = viewHelper.prepare_requested_resources(post_params["resources"])

    # get requested page and for which resource it is requested
    requested_page = int(post_params["page-geoportal"])
    requested_page_res = post_params["data-geoportal"]

    # get data source (rlp, other, ...)
    source = post_params.get("source", "")

    # get open data info
    only_open_data = post_params.get("onlyOpenData", 'false')

    start_time = time.time()
    # run search
    catalogue_id = PRIMARY_CATALOGUE
    searcher = Searcher(",".join(keywords),
                        requested_resources,
                        extended_search_params,
                        requested_page,
                        requested_page_res,
                        selected_facets,
                        order_by,
                        max_results,
                        search_bbox,
                        search_type_bbox,
                        only_open_data=only_open_data,
                        language_code=lang_code,
                        catalogue_id=catalogue_id,
                        host=HOSTNAME
                        )
    search_results = searcher.search_primary_catalogue_data(user_id=session_data.get("userid", ""))
    print_debug(EXEC_TIME_PRINT % ("total search in catalogue with ID " + str(catalogue_id), time.time() - start_time))

    # prepare search filters
    search_filters = viewHelper.get_search_filters(search_results)

    start_time = time.time()
    # rehash facets
    rehasher = Rehasher(search_results, search_filters)
    facets = rehasher.get_rehashed_categories()
    # set flag to indicate that the facet is one of the selected
    for facet_key, facet_val in list(selected_facets.items()):
        facet_key_trans = _(facet_key)
        for k in facet_val:
            k["parent_category"] = _(k["parent_category"])
        del selected_facets[facet_key]
        for chosen_facet in facet_val:
            _id = int(chosen_facet["id"])
            if _id < 0:
                continue
            for facet in facets[facet_key_trans]:
                if int(facet["id"]) == _id:
                    facet["is_selected"] = True
                    break
        selected_facets[facet_key_trans] = facet_val
    search_filters = rehasher.get_rehashed_filters()
    del rehasher
    print_debug(EXEC_TIME_PRINT % ("rehashing of facets", time.time() - start_time))

    start_time = time.time()
    # prepare pages to render for all resources
    pages = viewHelper.calculate_pages_to_render(search_results, requested_page, requested_page_res)
    print_debug(EXEC_TIME_PRINT % ("calculating pages to render", time.time() - start_time))

    # start_time = time.time()
    # # generate inspire feed urls
    # search_results = viewHelper.gen_inspire_url(search_results)
    # print_debug(EXEC_TIME_PRINT % ("preparing inspire urls", time.time() - start_time))

    start_time = time.time()
    # generate extent graphics url
    search_results = viewHelper.gen_extent_graphic_url(search_results)
    print_debug(EXEC_TIME_PRINT % ("generating extent graphic urls", time.time() - start_time))

    start_time = time.time()
    # set attributes for wfs child modules
    search_results = viewHelper.set_children_data_wfs(search_results)
    print_debug(EXEC_TIME_PRINT % ("setting wfs children data", time.time() - start_time))

    start_time = time.time()
    # set state icon file paths
    search_results = viewHelper.set_iso3166_icon_path(search_results)
    print_debug(EXEC_TIME_PRINT % ("setting iso3166 icons", time.time() - start_time))

    # check for bounding box
    bbox = post_params.get("searchBbox", '')
    session_id = request.COOKIES.get(SESSION_NAME, "")
    check_search_bbox(session_id, bbox)

    # prepare data for rendering
    types = {
        'Suchbegriff(e):': 'searchText',
        'INSPIRE Themen:': 'inspireThemes',
        'ISO Kategorien:': 'isoCategories',
        'RP Kategorien:': 'customCategories',
        'Räumliche Einschränkung:': 'searchBbox',
        'Anbietende Stelle(n):': 'registratingDepartments',
        'Registrierung/Aktualisierung von:': 'regTimeBegin',
        'Registrierung/Aktualisierung bis:': 'regTimeEnd',
        'Datenaktualität von:': 'timeBegin',
        'Datenaktualität bis:': 'timeEnd',
    }
    results = {
        "user": session_data.get("user", ""),
        "userid": session_data.get("userid", ""),
        "loggedin": session_data.get("loggedin", ""),
        "source": source,
        "types": types,
        "keywords": keywords,
        "all_resources": resources,
        "resources": requested_resources,
        "search_results": search_results,
        "search_filters": search_filters,
        "facets": facets,
        "show_facets_count": 5,
        "selected_facets": selected_facets,
        "pages": pages,
        "download_url": HOSTNAME + "/mapbender/php/mod_getDownloadOptions.php?id=",
        "download_feed_url": HOSTNAME + "/mapbender/plugins/mb_downloadFeedClient.php?url=",
        "download_feed_inspire": HOSTNAME + "/mapbender/php/mod_inspireDownloadFeed.php?id=",
        "view_map_url": "//localhost/portal/karten.html?",
        "wms_action_url": HTTP_OR_SSL + HOSTNAME + "/mapbender/php/wms.php?",
        "OPEN_DATA_URL": OPEN_DATA_URL,
        "sources": viewHelper.get_source_catalogues(False)
    }

    # since we need to return plain text to the ajax handler, we need to use render_to_string
    start_time = time.time()
    view_content = render_to_string(template_name, results)
    print_debug(EXEC_TIME_PRINT % ("rendering view", time.time() - start_time))

    return GeoportalJsonResponse(html=view_content, params={}).get_response()


@check_browser
def get_data_info(request: HttpRequest):
    """ Searches for results in the mediawiki

    THIS IS A FEATURE THAT ISN'T IMPLEMENTED YET

    Args:
        request (HttpRequest): The incoming request
    Returns:
        JsonResponse: Contains data for the ajax call
    """
    post_params = request.POST.dict()
    template_name = "search_results.html"
    host = HTTP_OR_SSL + HOSTNAME
    # get language
    lang = request.LANGUAGE_CODE

    # prepare search tags (keywords)
    keywords = post_params["terms"].split(",")
    list_all = False
    if len(keywords) == 1 and keywords[0] == '' or keywords[0] == '*':
        keywords = ["*"]
        list_all = True

    searcher = Searcher(keywords=keywords,
                        language_code=lang)
    if list_all:
        search_results = searcher.get_info_all_pages()
    else:
        search_results = searcher.get_info_search_results()
    search_results = viewHelper.prepare_info_search_results(search_results, list_all, lang)
    search_results = viewHelper.resolve_internal_external_info(search_results, searcher)

    params = {
        "lang": lang,
        "list_all": list_all,
        "HOSTNAME": host,
        "search_results": search_results,
        "is_info_search": True,
        "source": "info",
        "sources": viewHelper.get_source_catalogues(False),
    }
    # since we need to return plain text to the ajax handler, we need to use render_to_string
    view_content = render_to_string(template_name, params)

    return GeoportalJsonResponse(html=view_content, params={"directly_open": True}).get_response()


@check_browser
def get_permission_email_form(request: HttpRequest):
    """ Returns rendered email permission template.

    Reacts on an ajax call and renders an email form for requesting access permission to a specific resource.

    Args:
        request (HttpRequest): The incoming request
    Returns:
        JsonResponse: Contains the prerendered html for the form
    """
    template = "permission_email_form.html"
    params_GET = request.GET.dict()
    session_data = get_mb_user_session_data(request)
    user = session_data.get("user", "")
    mb_user = MbUser.objects.get(mb_user_name=user)
    mb_user_mail = mb_user.mb_user_email
    data_id = params_GET.get("layerId")
    data_name = params_GET.get("layerName")
    title = _("Send permission request")
    subject = "[" + HOSTNAME + "] " + _("Permission request for ") + str(data_id)
    draft = _("Please give me permission to view the resource \n'") + data_name +\
            _("'\n It has the ID ") + str(data_id) +\
            _(".\n\n Thank you very much\n\n") +\
            user + "\n" +\
            mb_user_mail
    params = {
        "data_provider": params_GET.get("dataProvider", ""),
        "subject": subject,
        "title": title,
        "draft": draft,
    }
    html = render_to_string(template_name=template, context=params, request=request)

    return GeoportalJsonResponse(html=html).get_response()


@check_browser
def send_permission_email(request: HttpRequest):
    """ Sends a permission email

    Args:
        request (HttpRequest): The incoming request
    Returns:
        JsonResponse: Contains the success/fail status
    """
    params_GET = request.GET.dict()
    address = params_GET.get("address", None)
    subject = params_GET.get("subject", None)
    message = params_GET.get("message", None)
    success = True

    try:
        send_mail(
            subject=subject,
            message=message,
            from_email="",  # ToDo: Insert webserver mailer
            recipient_list=[address],
            fail_silently=False
        )
    except smtplib.SMTPException:
        logger.error("Could not send mail: " + subject + ", to " + address)
        success = False

    return GeoportalJsonResponse(success=success).get_response()


@check_browser
def terms_of_use(request: HttpRequest):
    """ Fetches the terms of use for a specific search result

    Args:
        request (HttpRequest): The incoming request
    Returns:
        JsonResponse: Contains the required data
    """
    html = ""
    params_GET = request.GET.dict()
    lang_code = request.LANGUAGE_CODE
    href = params_GET.get("href")
    id = params_GET.get("id")
    resource = params_GET.get("resourceType")
    if resource == "dataset":
        resource = "wms"
    if resource == "wmc" or resource == "other-catalogue":
        # wmc has no disclaimer
        return GeoportalJsonResponse(html=html).get_response()

    html = viewHelper.generic_srv_disclaimer(resource=resource, service_id=id, language=lang_code)

    if len(html) > 0:
        template = "terms_of_use.html"
        params = {
            "content": html,
            "href": href
        }

        html = render_to_string(template_name=template, context=params)
    return GeoportalJsonResponse(html=html).get_response()


#ToDo: Check behaviour -> delete after a while
"""
@check_browser
def write_gml_session(request: HttpRequest):
    params_GET = request.GET.dict()
    lat_lon = params_GET.get("latLon", "{}")
    lat_lon = json.loads(lat_lon)
    session_id = request.COOKIES.get("sessionid", "")
    write_gml_to_session(lat_lon=lat_lon, session_id=session_id)
"""
