from django.http import HttpRequest, HttpResponse
from django.shortcuts import redirect
from wagtail.admin.panels import FieldPanel
from wagtail.blocks import CharBlock, RichTextBlock, StreamBlock, StructBlock
from wagtail.fields import StreamField
from wagtail.images.blocks import ImageChooserBlock
from wagtail.models import Page


class FullBleedImageBlock(StructBlock):
    image = ImageChooserBlock()
    caption = CharBlock(required=False)

    class Meta:
        icon = "image"
        label = "Full-bleed image"
        template = "pages/blocks/full_bleed_image.html"


class PullQuoteBlock(StructBlock):
    quote = CharBlock()
    attribution = CharBlock(required=False)

    class Meta:
        icon = "openquote"
        label = "Pull quote"
        template = "pages/blocks/pull_quote.html"


class TwoColumnBlock(StructBlock):
    left = RichTextBlock()
    right = RichTextBlock()

    class Meta:
        icon = "grip"
        label = "Two columns"
        template = "pages/blocks/two_column.html"


class RichContentStreamBlock(StreamBlock):
    rich_text = RichTextBlock(icon="pilcrow")
    full_bleed_image = FullBleedImageBlock()
    pull_quote = PullQuoteBlock()
    two_column = TwoColumnBlock()


class HomePage(Page):
    body = StreamField(RichContentStreamBlock(), blank=True, use_json_field=True)

    content_panels = Page.content_panels + [
        FieldPanel("body"),
    ]

    parent_page_types = ["wagtailcore.Page"]
    subpage_types = ["pages.BrochurePage", "pages.MembersIndexPage"]

    class Meta:
        verbose_name = "Home page"


class BrochurePage(Page):
    body = StreamField(RichContentStreamBlock(), blank=True, use_json_field=True)

    content_panels = Page.content_panels + [
        FieldPanel("body"),
    ]

    parent_page_types = ["pages.HomePage", "pages.BrochurePage"]
    subpage_types = ["pages.BrochurePage"]

    class Meta:
        verbose_name = "Brochure page"

    def get_context(self, request: HttpRequest, *args, **kwargs) -> dict:
        context = super().get_context(request, *args, **kwargs)
        context["child_pages"] = self.get_children().live().specific()
        return context


class MembersIndexPage(Page):
    content_panels = Page.content_panels

    parent_page_types = ["pages.HomePage"]
    subpage_types: list[str] = []

    class Meta:
        verbose_name = "Members index page"

    def serve(self, request: HttpRequest, *args, **kwargs) -> HttpResponse:
        if not request.user.is_authenticated or not request.user.is_active:
            return redirect(f"/accounts/login/?next={request.path}")
        # Additional approval check will be added when member approval is built
        return super().serve(request, *args, **kwargs)
