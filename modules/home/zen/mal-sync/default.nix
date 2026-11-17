# MAL-Sync, packaged like rycee's firefox-addons (and nixpkgs' Firefox
# add-ons): the AMO release pinned by version and hash. Called with rycee's
# buildFirefoxXpiAddon; to bump, take the new file URL and sha256 from
#   https://addons.mozilla.org/api/v5/addons/addon/mal-sync/
{
  lib,
  buildFirefoxXpiAddon,
}:
buildFirefoxXpiAddon rec {
  pname = "mal-sync";
  version = "0.12.5";
  addonId = "{c84d89d9-a826-4015-957b-affebd9eb603}";
  url = "https://addons.mozilla.org/firefox/downloads/file/4999907/mal_sync-${version}.xpi";
  sha256 = "5ee3c2a032d4605ec884ef7f9dee62716cb33bf467b8f03640d3610ce63190a1";

  meta = {
    homepage = "https://malsync.moe";
    description = "Integrates MyAnimeList, AniList, Kitsu, Simkl and MangaBaka into streaming and manga sites, syncing watch and read progress";
    license = lib.licenses.gpl3Only;
    # API permissions from AMO; its ~700 host permissions (the supported
    # sites) are left out.
    mozPermissions = [
      "storage"
      "alarms"
      "notifications"
      "declarativeNetRequestWithHostAccess"
      "scripting" # optional
    ];
    platforms = lib.platforms.all;
  };
}
