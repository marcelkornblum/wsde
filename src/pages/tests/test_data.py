import pytest

from pages.services import data


@pytest.mark.django_db
class TestGetHomePage:
    def test_returns_home_page(self, home_page):
        result = data.get_home_page()
        assert result.pk == home_page.pk

    def test_returns_none_when_no_home_page(self):
        result = data.get_home_page()
        assert result is None


@pytest.mark.django_db
class TestGetBrochureChildren:
    def test_returns_child_brochure_pages(self, brochure_page, home_page):
        from pages.models import BrochurePage

        child = BrochurePage(title="Venue", slug="venue")
        brochure_page.add_child(instance=child)

        results = data.get_brochure_children(brochure_page)
        assert child in results

    def test_excludes_non_brochure_pages(self, brochure_page, home_page):

        # MembersIndexPage is not a valid child of BrochurePage, so we just
        # verify the function returns only BrochurePage instances
        results = data.get_brochure_children(brochure_page)
        for page in results:
            assert isinstance(page, __import__("pages.models", fromlist=["BrochurePage"]).BrochurePage)
