import factory
from wagtail.models import Page

from pages.models import BrochurePage, HomePage, MembersIndexPage


class HomePageFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = HomePage

    title = "Home"
    slug = factory.Sequence(lambda n: f"home-{n}")

    @classmethod
    def _create(cls, model_class, *args, **kwargs):
        parent = kwargs.pop("parent", Page.objects.filter(depth=1).first())
        instance = model_class(*args, **kwargs)
        parent.add_child(instance=instance)
        return instance


class BrochurePageFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = BrochurePage

    title = factory.Sequence(lambda n: f"Brochure Page {n}")
    slug = factory.Sequence(lambda n: f"brochure-{n}")

    @classmethod
    def _create(cls, model_class, *args, **kwargs):
        parent = kwargs.pop("parent")
        instance = model_class(*args, **kwargs)
        parent.add_child(instance=instance)
        return instance


class MembersIndexPageFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = MembersIndexPage

    title = "Members"
    slug = factory.Sequence(lambda n: f"members-{n}")

    @classmethod
    def _create(cls, model_class, *args, **kwargs):
        parent = kwargs.pop("parent")
        instance = model_class(*args, **kwargs)
        parent.add_child(instance=instance)
        return instance
