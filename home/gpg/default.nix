{ ... }:
{
  home.file.gpg = {
    source = ./gpg.conf;
    target = ".gnupg/gpg-agent.conf";
  };
}
