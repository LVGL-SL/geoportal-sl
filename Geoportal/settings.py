"""
Django settings for userstuff project.

Generated by 'django-admin startproject' using Django 2.1.3.

For more information on this file, see
https://docs.djangoproject.com/en/2.1/topics/settings/

For the full list of settings and their values, see
https://docs.djangoproject.com/en/2.1/ref/settings/
"""
# Build paths inside the project like this: os.path.join(BASE_DIR, ...)
import environ
import os

from django.utils.translation import gettext_lazy as _
from django.utils.log import DEFAULT_LOGGING


env = environ.Env()
environ.Env.read_env()

# BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE_DIR = "/opt/geoportal/GeoPortal.sl"
PROJECT_DIR = "/opt/geoportal/"
SESSION_NAME = 'PHPSESSID'
# Quick-start development settings - unsuitable for production
# See https://docs.djangoproject.com/en/2.1/howto/deployment/checklist/

SECRET_KEY = env("SECRET_KEY")

DEBUG = env("DEBUG", default=False)

DEFAULT_LOGGING['handlers']['console']['filters'] = []

HOSTNAME = env("HOSTNAME", default='localhost')
HTTP_OR_SSL = env("HTTP_OR_SSL", default="http://")
SEARCH_API_PROTOCOL = env("SEARCH_API_PROTOCOL", default="http")

ALLOWED_HOSTS = env("ALLOWED_HOSTS", default=[
                    'localhost', '127.0.0.1', HOSTNAME, ])

INTERNAL_IPS = env("INTERNAL_IPS", default=[])

# Mediawiki
INTERNAL_PAGES_CATEGORY = "Portalseite"

# Mapviewer
IFRAME_HEIGHT = 700
IFRAME_WIDTH = 2000

# Set a bool flag if internal API calls shall be verifies via ssl or not
INTERNAL_SSL = False

# Search module settings
PRIMARY_CATALOGUE = 2
PRIMARY_SRC_IMG = "primary_results.png"
DE_CATALOGUE = 2
DE_SRC_IMG = "de_results.png"
EU_CATALOGUE = 4
EU_SRC_IMG = "eu_results.png"
OPEN_DATA_URL = "https://okfn.org/opendata/"

# Gui settings
DEFAULT_GUI = "Geoportal-SL"
MODERN_GUI = "Geoportal-SL-2020"

# WMC ID that should be loaded on mobile devices
MOBILE_WMC_ID = None

# Social networking and news feeds
TWITTER_NAME = ""
RSS_FILE = "http://www.geoportal.rlp.de" + \
    "/mapbender/geoportal/news/georss.xml"

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.humanize',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django_extensions',
    'useroperations',
    'news',
    'crispy_forms',
    'searchCatalogue',
    'captcha',
    'django_user_agents',
    'resourceManager',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.locale.LocaleMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'django_user_agents.middleware.UserAgentMiddleware',
]

ROOT_URLCONF = 'Geoportal.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR + "/templates"],
        'OPTIONS': {
            'loaders': [
                ('django.template.loaders.cached.Loader', [
                    'django.template.loaders.filesystem.Loader',
                    'django.template.loaders.app_directories.Loader',
                ]),
            ],
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'Geoportal.wsgi.application'

# Database
# https://docs.djangoproject.com/en/2.1/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'OPTIONS': {
            'options': '-c search_path=django,mapbender,public'
        },
        'NAME': env("DATABASE_NAME", default="mapbender"),
        'USER': env("DATABASE_USER", default=""),
        'PASSWORD': env("DATABASE_PASSWORD", default=""),
        'HOST': env("DATABASE_HOST", default=""),
        'PORT': env("DATABASE_PORT", default=""),
    }
}

# Password validation
# https://docs.djangoproject.com/en/2.1/ref/settings/#auth-password-validators

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME':
        'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME':
        'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME':
        'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME':
        'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

# Internationalization
# https://docs.djangoproject.com/en/2.1/topics/i18n/

LANGUAGES = [
    ('de', _('German')),
    ('en', _('English')),
]
LANGUAGE_CODE = 'de'  # Default language
MULTILINGUAL = True  # whether to use multiple languages or not

LOCALE_PATHS = [
    os.path.join(BASE_DIR, 'searchCatalogue/locale'),
    os.path.join(BASE_DIR, 'useroperations/locale'),
]

TIME_ZONE = 'UTC'

# These internationalization setting has to be always True
USE_I18N = True

USE_L10N = True

USE_TZ = True

LOCALE_PATHS = (os.path.join(BASE_DIR, 'locale'), )

# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/2.1/howto/static-files/

STATIC_URL = '/static/'
STATIC_ROOT = BASE_DIR + "/static/"

# Mailing settings
EMAIL_BACKEND = env(
    "EMAIL_BACKEND", default='django.core.mail.backends.smtp.EmailBackend')
EMAIL_USE_TLS = env("EMAIL_USE_TLS", default=False)
EMAIL_HOST = env("EMAIL_HOST", default='')
EMAIL_HOST_USER = env(
    "EMAIL_HOST_USER", default='geoportal.saarland@lvgl.saarland.de')
DEFAULT_FROM_EMAIL = env("DEFAULT_FROM_EMAIL", default=EMAIL_HOST_USER)
DEFAULT_TO_EMAIL = EMAIL_HOST_USER
EMAIL_PORT = env("EMAIL_PORT", default=25)
ROOT_EMAIL_ADDRESS = env("ROOT_EMAIL_ADDRESS", default="root@geoportal.tld")
EMAIL_CONTACT = env("EMAIL_CONTACT", default="root@geoportal.tld")

# Recaptcha Config
USE_RECAPTCHA = env("USE_RECAPTCHA", default=0)
GOOGLE_RECAPTCHA_SECRET_KEY = env("GOOGLE_RECAPTCHA_SECRET_KEY", default='')
GOOGLE_RECAPTCHA_PUBLIC_KEY = env("GOOGLE_RECAPTCHA_PUBLIC_KEY", default='')

# WMC ID that should be loaded on mobile devices
MOBILE_WMC_ID = None

# Directory for inspire Downloads
INSPIRE_ATOM_DIR = "/data2/inspiredownloads/"  # eg: "/var/www/html/inspiredownloads/"
INSPIRE_ATOM_ALIAS = "/inspiredownloads/"  # eg: "/inspiredownloads/"

# Farward Proxy
PROXIES = {
    "http": env("PROXY_HTTP", default=""),
    "https": env("PROXY_HTTPS", default="")
}

# Memcached
MEMCACHED_SESSION_PREFIX = env("MEMCACHED_SESSION_PREFIX", default='memc.sess.')
