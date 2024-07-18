import threading
import random
import string

import bcrypt
import requests
from lxml import html
import json
from Geoportal.settings import HOSTNAME, HTTP_OR_SSL, INTERNAL_SSL, MULTILINGUAL, BASE_DIR
from Geoportal.utils import utils
from searchCatalogue.utils.searcher import Searcher
from useroperations.models import *
from useroperations.settings import INSPIRE_CATEGORIES, ISO_CATEGORIES
from django.core.exceptions import MultipleObjectsReturned
from operator import and_
from functools import reduce


def random_string(stringLength=15):
    letters = string.ascii_lowercase
    return ''.join(random.choice(letters) for i in range(stringLength))


def __set_tag(dom, tag, attribute, prefix):
    """ Checks the DOM for a special tag and changes the attribute according to the provided value

    Args:
        dom: The document object model
        tag: The tag which we are looking for (e.g. <a>)
        attribute: The attribute that has to be changed
        prefix: The 'https://xyz' prefix of a route
    Returns:
        Nothing, dom is mutable
    """
    protocol = "http"
    searcher = Searcher()
    _list = dom.cssselect(tag)
    for elem in _list:
        attrib = elem.get(attribute)
        if tag == 'a':
            # check if the page we want to go to is an internal or external page
            title = elem.get("title", "").replace(" ", "_")
            #At least temporarily removed the check on title being initial due to internal links on 
            #mediawiki pages like "information" not working anymore
            #if title and searcher.is_article_internal(title):
            if searcher.is_article_internal(title):
                attrib = "/article/" + title
        if protocol not in attrib:
            elem.set(attribute, prefix + attrib)


def set_links_in_dom(dom):
    """ Since the wiki (where the DOM comes from) is currently(!!!) not on the same machine as the Geoportal,
    we need to change all links to the machine where the wiki lives

    Args:
        dom:
    Returns:
    """
    prefix = HTTP_OR_SSL + HOSTNAME

    # handle links
    thread_list = []
    thread_list.append(threading.Thread(target=__set_tag, args=(dom, "a", "href", prefix)))
    thread_list.append(threading.Thread(target=__set_tag, args=(dom, "img", "src", prefix)))
    utils.execute_threads(thread_list)


def get_wiki_body_content(wiki_keyword, lang, category=None):
    """ Returns the HTML body content of the corresponding mediawiki page

    Args:
        wiki_keyword (str): A keyword that matches a mediawiki article title
        lang (str): The currently selected language
        category (str): A filter for internal or external categories
    Returns:
        str: The html content of the wiki article
    """
    # get mediawiki html
    # #6626 Reroll to old SL Version of the next 4 lines since we use a differenct concept than RLP 
    # to create and read mediawiki articles
    if MULTILINGUAL:
        url = HTTP_OR_SSL + '127.0.0.1' + "/mediawiki/index.php/" + wiki_keyword + "/" + lang + "#bodyContent"
    else:
        url = HTTP_OR_SSL + '127.0.0.1' + "/mediawiki/index.php/" + wiki_keyword + "#bodyContent"
    html_raw = requests.get(url, verify=INTERNAL_SSL)
    if html_raw.status_code != 200:
        raise FileNotFoundError

    html_con = html.fromstring(html_raw.content)

    # get body html div - due to translation module on mediawiki, we need to fetch the parser output
    try:
        body_con = html_con.cssselect(".mw-parser-output")
        if len(body_con) == 1:
            body_con = body_con[0]
    except KeyError:
        return "Error: Check if mediawiki translation package is installed!"
    except TypeError:
        return "Error: mw-parser-output ist not unique"

    # set correct src/link for all <img> and <a> tags
    set_links_in_dom(body_con)

    # render back to html
    return html.tostring(doc=body_con, method='html', encoding='unicode')


def get_landing_page(lang: str):
    """ Returns the landing page content (favourite wmcs)

    Args:
        lang (str): The language for which the data shall be fetched
    Returns:
        A dict containing an overview of how many organizations, topics, wmcs, services and so on are available
    """
    ret_dict = {}
    # get favourite wmcs
    searcher = Searcher(keywords="", result_target="", resource_set=["wmc"], page=1, order_by="rank", host=HOSTNAME, max_results=10)
    search_results = searcher.search_primary_catalogue_data()
    ret_dict["wmc"] = search_results.get("wmc", {}).get("wmc", {}).get("srv", [])

    # get number of wmc's
    ret_dict["num_wmc"] = search_results.get("wmc", {}).get("wmc", {}).get("md", {}).get("nresults")

    # get number of organizations
    ret_dict["num_orgs"] = len(get_all_organizations())

    # get number of applications
    ret_dict["num_apps"] = len(get_all_applications())

    # get number of topics
    len_inspire = len(get_topics(lang, INSPIRE_CATEGORIES).get("tags", []))
    len_iso = len(get_topics(lang, ISO_CATEGORIES).get("tags", []))
    ret_dict["num_inspire_topics"] = len_inspire
    ret_dict["num_iso_topics"] = len_iso
    ret_dict["num_topics"] = len_inspire + len_iso
    
    # get number of datasets and layers
    tmp = {
        "dataset": "num_dataset",
        "wms": "num_wms",
    }
    for key, val in tmp.items():
        searcher = Searcher(keywords="", result_target="", resource_set=[key], host=HOSTNAME)
        search_results = searcher.search_primary_catalogue_data()
        ret_dict[val] = search_results.get(key, {}).get(key, {}).get("md", {}).get("nresults")

    return ret_dict


def get_all_organizations():
    """ Returns a list of all data publishing organizations

    Returns:
         A list of all organizations which publish data
    """
    searcher = Searcher(keywords="", resource_set=["wmc"], page=1, order_by="rank", host=HOSTNAME)

    return searcher.search_all_organizations()


def get_all_applications():
    """ Returns a list of all available applications

    Returns:
         A list of all applications
    """
    searcher = Searcher(keywords="", resource_set=["application"], host=HOSTNAME, max_results=55)
    return searcher.search_primary_catalogue_data().get("application", {}).get("application", {}).get("application", {}).get("srv", [])


def get_topics(language, topic_type: str):
    """ Returns a list of all inspire topics available

    Returns:
         A list of all organizations which publish data
    """
    searcher = Searcher(
        keywords="",
        resource_set=["wmc"],
        page=1,
        order_by="rank",
        host=HOSTNAME
    )

    return searcher.search_topics(language, topic_type)


def bcrypt_password(pw: str, user: MbUser):
    """ Encrypts the given password using a user salt.

    Needed for checking if a given password matches a user's password

    Args:
        pw (str): The given password
        user (MbUser): The MbUser object
    Returns:
         The encrypted password string
    """
    return (str(bcrypt.hashpw(pw.encode('utf-8'), user.password.encode('utf-8')), 'utf-8'))


def model_objects_case_insensitive_get(model, **kwargs):
    """ Database lookup for "columnname: value"-pairs of a model to return one single model-object as the model.objects.get-Method does
        with an additional case insensitive lookup

    Args:
        model (Type): The django model class to query
        **kwargs: Variable number of keyword arguments representing column-value pairs to filter the queryset
    Returns:
        model[Type] The model instance that matches the filtering criteria, if found

    Raises:
        ValueError: If no matching instance is found
        ValueError: If multiple instances match the given criteria

    Example usage:
            try:
                user = useroperations_helper.model_objects_case_insensitive_get(MbUser, mb_username = username, mb_user_email = email)
            except ValueError as e:
                #Create useful errormessage here
    """


    queryset = reduce(and_, [model.objects.filter(**{f'{column_name}__iexact': value_to_filter_on}) for column_name, value_to_filter_on in kwargs.items()])
    result_count = queryset.count()

    if result_count == 1:
        return model(**queryset.values().first())  # Convert dictionary to model object
    elif result_count == 0:
        raise ValueError(f'{model.__name__} matching query does not exist.')
    else:
        raise MultipleObjectsReturned('get() returned more than one {} -- it returned {}! Lookup parameters were {}__iexact={!r}'.format(
            model.__name__, result_count, kwargs
        ))
    

def get_article_conf(conf_file_name, lang, is_url = False):
    """ Returns the HTML body content of the corresponding mediawiki page

    Args:
        conf_file_name (str): A keyword that matches a mediawiki article title
        lang (str): The currently selected language
    Returns:
        str: The html content of the wiki article
    """
    if is_url:
        return False

    else:
        config_name = BASE_DIR + '/useroperations/article_conf/' + conf_file_name + ".json"
        #json_config = open(config_name)


        try:
            with open(config_name, encoding='utf-8') as file:
                data = json.load(file)
                return data
        except Exception as e:
            return False
