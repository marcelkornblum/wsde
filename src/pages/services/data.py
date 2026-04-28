from pages.models import BrochurePage, HomePage


def get_home_page() -> HomePage | None:
    return HomePage.objects.live().first()


def get_brochure_children(page: BrochurePage) -> list[BrochurePage]:
    return list(page.get_children().live().type(BrochurePage).specific())
