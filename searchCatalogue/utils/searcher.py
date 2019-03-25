"""

Author: Michel Peltriaux
Organization: Spatial data infrastructure Rheinland-Pfalz, Germany
Contact: michel.peltriaux@vermkv.rlp.de
Created on: 22.01.19

"""
import hashlib
import random
from collections import OrderedDict
from json import JSONDecodeError

import requests
import threading

from copy import copy

from Geoportal import helper
from Geoportal.settings import RLP_CATALOGUE
from searchCatalogue.settings import PROXIES
from searchCatalogue.utils.url_conf import *


class Searcher:

    def __init__(self, keywords="",
                 resource_set="dataset",
                 extended_search_params="",
                 page=1,
                 page_res="",
                 selected_facets={},
                 order_by="",
                 bbox=None,
                 type_bbox=None,
                 language_code="de",
                 catalogue_id=RLP_CATALOGUE,
                 only_open_data='false'):
        """ Constructor

        Args:
            keywords: The search text
            resource_set: The resource for that a search shall be started
            extended_search_params: The search parameters from the extended search menu
            page: The page that is requested
            page_res: For which resource is the page requested
            selected_facets: Which facets/filters/categories are currently selected in the search module
            order_by: Which order shall be used
            bbox: The bbox for e.g. intersection
            type_bbox: The type of bbox
            language_code: In which language shall the results be returned
            catalogue_id: Which catalogue is fetched
        """
        self.keywords = keywords
        self.output_format = "json"
        self.result_target = "webclient"
        self.search_pages = page
        self.search_resources = resource_set
        self.extended_params = extended_search_params
        self.search_page_resource = page_res
        self.selected_facets = selected_facets
        self.order_by = order_by
        self.bbox = bbox
        self.typeBbox = type_bbox
        self.catalogue_id = catalogue_id
        self.language_code = language_code
        self.only_open_data = only_open_data

        self.org_ids = []
        self.iso_ids = []
        self.custom_ids = []
        self.inspire_ids = []
        self.lock = threading.BoundedSemaphore()


        # get random search id
        md_5 = hashlib.md5()
        microseconds = str(random.getrandbits(128)).encode("utf-8")
        md_5.update(microseconds)
        self.search_id = md_5.hexdigest()

    def __prepare_selected_facets(self):
        """ Find the ids of the selected facets in all facets

        Returns:
            nothing
        """
        # prepare registrating departments facets
        for facet_key, facet_val in self.selected_facets.items():
            for facet in facet_val:
                if facet.get("parent_category") == "ISO 19115":
                    self.iso_ids.append(facet.get("id"))
                elif facet.get("parent_category") == "INSPIRE":
                    self.inspire_ids.append(facet.get("id"))
                elif facet.get("parent_category") == "Sonstige":
                    self.custom_ids.append(facet.get("id"))
                elif facet.get("parent_category") == "Organisationen":
                    self.org_ids.append(facet.get("id"))


    def __get_resource_results(self, url, params: dict, resource, result: dict):
        """ Use a GET request to retrieve the search results for a specific data resource

        Args:
            url: The url to be fetched from
            params: The parameters for the GET request as dict
            resource: The name of the data resource that shall be fetched
            result: The return dict that will be changed during this function
        Returns:
            nothing
        """
        response = requests.get(url, params)
        result[resource] = response.json()

    def get_categories_list(self):
        """ Get a list of all categories/facets from the database using a GET request

        Returns:
            Returns the categories which have been found during the search
        """
        url = URL_BASE + URL_SEARCH_RLP_SUFFIX
        params = {
            "outputFormat": self.output_format,
            "resultTarget": self.result_target,
            "searchResources": self.search_resources,
            "searchId": self.search_id,
            "languageCode": self.language_code,
        }
        response = requests.get(url, params)
        response = response.json()
        categories = response["categories"]["searchMD"]["category"]
        return categories


    def get_search_results_rlp(self):
        """ Performs the search

        Search parameters will be used from the Searcher object itself.

        Returns:
            dict: Contains the search results
        """
        url = URL_BASE + URL_SEARCH_RLP_SUFFIX
        self.__prepare_selected_facets()
        params = {
            "searchText": self.keywords,
            "outputFormat": self.output_format,
            "resultTarget": self.result_target,
            "searchPages": 1,   # default for non directly requested categories
            "searchResources": self.search_resources,
            "searchId": self.search_id,
            "resolveCoupledResources": 'true',
            "registratingDepartments": ",".join(self.org_ids),
            "isoCategories": ",".join(self.iso_ids),
            "customCategories": ",".join(self.custom_ids),
            "inspireThemes": ",".join(self.inspire_ids),
            "orderBy": self.order_by,
            "searchBbox": self.bbox,
            "searchTypeBbox": self.typeBbox,
            "languageCode": self.language_code,
            "restrictToOpenData": self.only_open_data,
        }
        params.update(self.extended_params)
        result = {}
        thread_list = []
        if len(self.search_resources) == 1 and self.search_resources[0] == '':
            return result
        for resource in self.search_resources:
            if resource == self.search_page_resource:
                # use requested page
                params["searchPages"] = self.search_pages
            else:
                params["searchPages"] = 1
            params["searchResources"] = resource
            thread = threading.Thread(target=self.__get_resource_results, args=(url, copy(params), resource, result))
            thread_list.append(thread)
            #self.__get_resource_results(url, params, resource, result)
        helper.execute_threads(thread_list)
        return result

    def __get_resource_results_de(self, resource, params: dict, results: dict, url):
        """ Executes API calls for the german catalogue for each resource in an own thread

        Args:
            resource:    The name of the data resource that will be fetched
            params:      The parameters for the GET request as a dict
            results:     The result dict which will be filled with the search results during this function's call
            url:         The GET url
        Returns:
            nothing
        """

        response = requests.get(url, params)
        try:
            response = response.json()
            results[resource] = response
        except JSONDecodeError:
            return

    def get_search_results_de(self):
        """ Main function for calling the german catalogue

        Returns:
            dict: Contains all search results
        """
        url = URL_BASE + URL_SEARCH_DE_SUFFIX
        params = {
            "catalogueId": self.catalogue_id,
            "searchText": self.keywords,
            "searchResources": "",
            "searchPages": self.search_pages,
            "maxResults": 5,
        }
        thread_list = []
        results = OrderedDict()
        for resource in self.search_resources:
            if resource == self.search_page_resource:
                # use requested page
                params["searchPages"] = self.search_pages
            else:
                params["searchPages"] = 1
            params["searchResources"] = resource
            thread_list.append(threading.Thread(target=self.__get_resource_results_de, args=(resource, copy(params), results, url)))
        helper.execute_threads(thread_list)

        return results

    def get_spatial_data(self, search_texts):
        """ Performs a spatial filtered search

        Args:
            search_texts: All search words in a list
        Returns:
            Returns the spatial search results from the database
        """
        ret_val = []
        url = URL_SPATIAL_BASE + URL_SPATIAL_SEARCH_SUFFIX
        for search_text in search_texts:
            params = {
                "outputFormat": self.output_format,
                "resultTarget": "web",
                "searchEPSG": 4326,
                "maxResults": 15,
                "maxRows": 15,
                "searchText": search_text
            }
            response = requests.get(url, params, proxies=PROXIES)
            result = response.json()
            result["keyword"] = search_text
            ret_val.append(result)


        return ret_val

    def __get_single_info_result(self, params: dict, results: dict):
        """ Runs a single thread GET request

        Args:
            params: Parameters for the GET request
            results: The dict to be modified
        Returns:
            nothing
        """
        response = requests.get(url=URL_SEARCH_INFO, params=params)
        response = response.json()
        params["srsearch"] = params["srsearch"].replace("*", "")
        if results.get(params["srsearch"], None) is None:
            results[params["srsearch"]] = []
        # remove asterisks to avoid rendering them to the user!
        results[params["srsearch"]].append(response)

    def get_info_result_category(self, search_result):
        """

        Args:
            search_result (dict): The search result that shall be checked
        Returns:
             category (str): The categories for the search result
        """
        params = {
            "titles": search_result.get("title", ""),
            "action": "query",
            "format": "json",
            "prop": "categories",
        }
        response = requests.get(url=URL_SEARCH_INFO, params=params)
        response = response.json()
        response = response["query"]["pages"]
        for resp_key, resp_val in response.items():
            return resp_val.get("categories", [])

    def is_article_internal(self, title):
        """ Checks if the provided title is associated with an internal article

        Args:
            title (str): The title of the article
        Returns:
             bool: True if the article is internal, False otherwise
        """
        tmp = {
            "title": title
        }
        resp = self.get_info_result_category(tmp)
        for category in resp:
            if "Intern" in category.get("title", ""):
                return True
        return False

    def get_info_search_results(self):
        params = {
            "action": "query",
            "list": "search",
            "srsearch": self.keywords,
            "format": "json",
            "srwhat": ["text", "title", "nearmatch"]
        }
        # since the mediawiki API does not handle multiple search words, we need to iterate over all
        # keywords in the keywords array and search every time for all three srwhat types for hits
        thread_list = []
        results = {}
        for keyword in self.keywords:
            # append a asterisks for matching everything that contains this part
            params["srsearch"] = "*" + keyword + "*"
            for what in params["srwhat"]:
                params_cp = copy(params)
                params_cp["srwhat"] = what
                # create thread
                thread_list.append(threading.Thread(target=self.__get_single_info_result, args=(params_cp, results)))
        helper.execute_threads(thread_list)
        return results

    def get_info_all_pages(self):
        params = {
            "action": "query",
            "list": "allpages",
            "apprefix": "",
            "format": "json",
            "aplimit": 500,
        }
        results = {}
        response = requests.get(url=URL_SEARCH_INFO, params=params)
        response = response.json()
        results = response
        return results