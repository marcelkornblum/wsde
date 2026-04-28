import pytest


@pytest.mark.django_db
class TestPageParentRules:
    def test_home_page_allowed_under_root(self, root_page):
        from pages.models import HomePage

        home = HomePage(title="Home 2", slug="home2")
        # Should not raise
        root_page.add_child(instance=home)
        assert home.pk is not None

    def test_brochure_page_allowed_under_home(self, home_page):
        from pages.models import BrochurePage

        page = BrochurePage(title="Brochure", slug="brochure")
        home_page.add_child(instance=page)
        assert page.pk is not None

    def test_brochure_page_allowed_under_brochure(self, brochure_page):
        from pages.models import BrochurePage

        child = BrochurePage(title="Venue", slug="venue")
        brochure_page.add_child(instance=child)
        assert child.pk is not None

    def test_members_index_allowed_under_home(self, home_page):
        from pages.models import MembersIndexPage

        page = MembersIndexPage(title="Members", slug="members")
        home_page.add_child(instance=page)
        assert page.pk is not None


@pytest.mark.django_db
class TestMembersIndexAuth:
    def test_unauthenticated_user_is_redirected(self, rf, members_index_page):
        from django.contrib.auth.models import AnonymousUser

        request = rf.get("/members/")
        request.user = AnonymousUser()
        response = members_index_page.serve(request)
        assert response.status_code in (302, 301)

    def test_authenticated_unapproved_user_is_redirected(self, rf, members_index_page, django_user_model):
        user = django_user_model.objects.create_user(username="pending", password="pass", is_active=False)
        request = rf.get("/members/")
        request.user = user
        response = members_index_page.serve(request)
        assert response.status_code in (302, 301)
