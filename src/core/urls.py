from django.urls import include, path

from wagtail import urls as wagtail_urls
from wagtail.admin import urls as wagtailadmin_urls
from wagtail.documents import urls as wagtaildocs_urls

urlpatterns = [
    path("django-admin/", __import__("django.contrib.admin", fromlist=["site"]).site.urls),
    path("wagtail-admin/", include(wagtailadmin_urls)),
    path("documents/", include(wagtaildocs_urls)),
    path("accounts/", include("allauth.urls")),
    # App URLs go here
    # path("members/", include("members.urls")),
    # Wagtail catch-all — must be last
    path("", include(wagtail_urls)),
]
