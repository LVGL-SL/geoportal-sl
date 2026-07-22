from django.http import HttpResponse
from django.shortcuts import render
from Geoportal.decorator import check_browser
from Geoportal.settings import LANGUAGE_CODE, MULTILINGUAL
from Geoportal.geoportalObjects import GeoportalContext
from appArticle.models import ArticleConfig
from appArticle.utils import app_article_helper
from appArticle.utils.app_article_json_converter import JsonConverter


@check_browser
def app_article_view(request, article_keyword=""):
    """Renders a view for configured lists of datasets"""
    request.session["current_page"] = "app_article"
    if MULTILINGUAL:
        lang = request.LANGUAGE_CODE
    else:
        lang = LANGUAGE_CODE

    geoportal_context = GeoportalContext(request)

    results = app_article_helper.get_article_conf(article_keyword, lang)

    if results:
        template = 'app_article.html'
        
        #converter = JsonConverter()
        #results = converter.normalize(results)

#         context = {
#             "results": results,
#             "mobile_wmc_id": MOBILE_WMC_ID,
#             "slider_elements": ApplicationSliderElement.objects.order_by('rank'),
#             "dispatches": LandingPageDispatch.objects.filter(is_active=True),
#         }
        
        context = {
            "results": results,
        }
        
        geoportal_context.add_context(context=context)
    else:
        template = "404.html"

    return render(request, template, geoportal_context.get_context())


@check_browser
def app_article_json(request, article_keyword=""):
    """Download an article configuration as JSON."""
    if MULTILINGUAL:
        lang = request.LANGUAGE_CODE
    else:
        lang = LANGUAGE_CODE

    requested_language = request.GET.get('language', lang)

    article = None
    for language_code in [requested_language, 'all']:
        try:
            article = ArticleConfig.objects.get(
                article_keyword=article_keyword,
                language=language_code,
                is_active=True,
            )
            break
        except ArticleConfig.DoesNotExist:
            continue

    if not article:
        return render(request, '404.html', status=404)

    json_content = article.to_json_export()
    #filename = f"{article.article_keyword}_{article.language}.json" if article.language != 'all' else f"{article.article_keyword}.json"

    response = HttpResponse(json_content, content_type='application/json; charset=utf-8')
    #Download the file instead of displaying it in the browser
    #response['Content-Disposition'] = f'attachment; filename="{filename}"'
    return response