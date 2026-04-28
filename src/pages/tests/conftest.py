import pytest
from wagtail.models import Page


@pytest.fixture
def root_page():
    return Page.objects.filter(depth=1).first()


@pytest.fixture
def home_page(root_page):
    from pages.models import HomePage

    home = HomePage(
        title="Home",
        slug="test-home",
        show_in_menus=True,
    )
    root_page.add_child(instance=home)
    return home


@pytest.fixture
def brochure_page(home_page):
    from pages.models import BrochurePage

    page = BrochurePage(
        title="The Stag Do",
        slug="test-brochure",
    )
    home_page.add_child(instance=page)
    return page


@pytest.fixture
def members_index_page(home_page):
    from pages.models import MembersIndexPage

    page = MembersIndexPage(
        title="Members",
        slug="test-members",
    )
    home_page.add_child(instance=page)
    return page
