from django.core.management.base import BaseCommand


class Command(BaseCommand):
    help = "Ensure a HomePage exists at the Wagtail site root, creating one if needed."

    def handle(self, *args, **options):
        from wagtail.models import Page, Site

        from pages.models import HomePage

        if HomePage.objects.exists():
            self.stdout.write("✅  HomePage already exists — nothing to do.")
            return

        root = Page.objects.filter(depth=1).first()
        if root is None:
            self.stderr.write("❌  No root page found. Run migrations first.")
            return

        # Wagtail's initial migration creates a plain Page with slug "home".
        # Delete it so we can take its place cleanly.
        default_page = Page.objects.filter(depth=2, slug="home").first()
        if default_page is not None:
            # Move any Site pointing at this page to root temporarily
            Site.objects.filter(root_page=default_page).update(root_page=root)
            default_page.delete()

        home = HomePage(title="Home", slug="home", live=True)
        root.add_child(instance=home)

        # Point the default site at the new home page
        site = Site.objects.filter(is_default_site=True).first()
        if site is not None:
            site.root_page = home
            site.save()

        self.stdout.write(f"✅  Created HomePage (pk={home.pk}) at /home/.")
