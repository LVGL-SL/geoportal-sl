from django.urls import path
from .views import *

app_name = "appArticle"
urlpatterns = [
    path('<slug:article_keyword>/', app_article_view, name='app_article'),
    path('<slug:article_keyword>/json/', app_article_json, name='app_article__json')
]
