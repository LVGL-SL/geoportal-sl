from django.shortcuts import render
from django.http import HttpResponse, HttpResponseBadRequest
from pprint import pprint
from django.views.decorators.csrf import csrf_exempt
from useroperations.models import Wfs, Wms, InspireDownloads
from searchCatalogue.settings import PROXIES
from django.core.mail import send_mail
from Geoportal.settings import HOSTNAME, HTTP_OR_SSL, PROJECT_DIR, HOSTIP, EMAIL_HOST_USER
from django.utils.translation import gettext as _
from email.utils import parseaddr
import json
import re
import urllib
import requests
import shutil
import os

@csrf_exempt
def download(request):


    if request.META['HTTP_HOST'] not in ["127.0.0.1","localhost",HOSTNAME,HOSTIP]:
        return HttpResponse('Only internal requests!')

    #body = (json.loads(request.body.decode('utf-8')))

    # this needs to be ascii because then open function in line 104
    # somehow uses ascii by default which is not changeable in binary mode (wb)
    body_decoded = request.body.decode('ascii','ignore')

    wfslist = Wfs.objects.values('wfs_getfeature').distinct()
    wmslist = Wms.objects.values('wms_getmap').distinct()
    download_request = InspireDownloads()
    whitelist = []
    response = ""
    message = ""
    numURLs = 0

    try:
        body = json.loads(body_decoded)
    except ValueError:
        response = HttpResponse('Value error while decoding request body')

    # input validation
    if not re.match('^[0-9]{1,10}$', body['user_id']):
        response = HttpResponseBadRequest('user_id should be an integer with max 10 digits')

    if not parseaddr(body['user_email']):
        response = HttpResponseBadRequest('email not valid')

    if not re.match('^\d{13}$', str(body['timestamp'])):
        response = HttpResponseBadRequest('timestamp should be an integer with 13 digits')

    if not re.match('^[A-Za-z0-9.-_]+$', body['scriptname']):
        response = HttpResponseBadRequest('scriptname not valid, use A-Z a-z 0-9 . - _')

    if not re.match('^[A-Za-z0-9-]+$', body['uuid']):
        response = HttpResponseBadRequest('uuid not valid, use A-Z a-z 0-9 -')

    # build whitelist
    for url in wfslist:
        parsed = urllib.parse.urlparse(url['wfs_getfeature'])
        host = '{uri.scheme}://{uri.netloc}/'.format(uri=parsed)
        whitelist.append(host)

    for url in wmslist:
        parsed = urllib.parse.urlparse(url['wms_getmap'])
        host = '{uri.scheme}://{uri.netloc}/'.format(uri=parsed)
        whitelist.append(host)

    #check whitelist
    for id,url in enumerate(body['urls']):
        numURLs = numURLs + 1
        parsed = urllib.parse.urlparse(urllib.parse.unquote(url))
        host = '{uri.scheme}://{uri.netloc}/'.format(uri=parsed)
        if host not in whitelist:
            response = HttpResponse("host not in whitelist",status=418)

    if numURLs > 20:
        response = HttpResponse("maximum 20 tiles allowed", status=409)

    # check if directory has space left
    disk = shutil.disk_usage(PROJECT_DIR + "/mapbender/http/tmp/InspireDownload/")

    if "image" in body['urls'][0]:
        format = ".tiff"
    else:
        format = ""

    if format == ".tiff":
        if disk.free < numURLs * 60000000:
            response = HttpResponse("No space left please try again later!",status=400)
            message = _("No space left please try again later!")
    else:
        if disk.free < numURLs * 10000000:
            response = HttpResponse("No space left please try again later!",status=400)
            message = _("No space left please try again later!")

    # download and send email
    if response is "":

        os.mkdir(PROJECT_DIR + "/mapbender/http/tmp/InspireDownload/" + body['uuid'])

        for id, url in enumerate(body['urls']):

            if "/" in body['names'][id]:
                body['names'][id] = body['names'][id].replace("/", "-")

            response = requests.get(urllib.parse.unquote(url), stream=True, proxies=PROXIES, verify=False)

            with open(PROJECT_DIR + "/mapbender/http/tmp/InspireDownload/" + body['uuid'] + '/' + body['names'][id] + format, mode='wb') as out_file:
                shutil.copyfileobj(response.raw, out_file)
            del response

        shutil.make_archive(PROJECT_DIR + '/mapbender/http/tmp/InspireDownload/InspireDownload_' + body['uuid'], 'zip',
                            PROJECT_DIR + '/mapbender/http/tmp/InspireDownload/' + body['uuid'])
        shutil.rmtree(PROJECT_DIR + "/mapbender/http/tmp/InspireDownload/" + body['uuid'])

        if body['lang'] == 'de':
            message = "Dies ist Ihre Inspire Download Anfrage! Der Link wird für 24 Stunden gültig sein!" + "\n Link: " \
                      + HTTP_OR_SSL + HOSTNAME + '/mapbender/tmp/InspireDownload/InspireDownload_' + body['uuid'] + '.zip'
        else:
            message = "This is your Inspire Download request! The Link will be valid  for 24 hours!" + "\n Link: " \
                      + HTTP_OR_SSL + HOSTNAME + '/mapbender/tmp/InspireDownload/InspireDownload_' + body['uuid'] + '.zip'

        download_request.user_id = body['user_id']
        download_request.user_email = body['user_email']
        download_request.service_name = body['names'][0].split("Teil",1)[0]
        download_request.no_of_tiles = numURLs
        download_request.save()



        response = HttpResponse("ok")

    send_mail(
        _("Inspire Download"),
        _("Hello ") + body['user_name'] +
        ", \n \n" +
        message,
        EMAIL_HOST_USER,
        [body['user_email']],
        fail_silently=False,
    )

    return response
