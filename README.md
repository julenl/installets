# Installets

## What are Installets
Installets are simple and self documented scripts which install and configure things without user input.

- Installets are shell scripts which you can just copy&paste from the website to your terminal and will get you stuff done automatically without you doing anything else (or giving you the chance to make a mistake ;) ).

- Installets are written to work for a given operating system after a fresh installation. This ensures that you can get the thing working in a sort of _hello world_ way. If the _hello world_ does not work, there is no point on moving forward.

- Installets have a given format, including some commented out keywords at the beginning. All user-oriented variables should be declared right at the beginning, to give the user the chance to know about them and change them. Using a given format makes it easier to search trough the installet library. If you want to build your own installet, try using the template `template_lamp_ubuntu.sh`.

## Motivation
GNU/Linux based operating systems have great packaging systems that allow us to install all sorts of software. However, sometimes, some services require further steps than just `apt install package` in order to actually see it working. The instructions on how to get the things working can also be found on tons of websites and blogs, but they usually mix up _text to read_ with `commands to execute`, and include interactive steps such as using a text editor to edit the configuration files.

Because doing things by hand is a potential source for errors, a fully automated process is a way to make sure you have the most chances the thing will work.

And if it doesn't you don't have to waste so much time trying to explain the community about your system settings and the steps you did, just send a link to the installet :)

## Structure
This project just got started, so there is not so much content yet. But the idea is, that there will be different folders on the repository, each one for a different operating system.

Each folder will contain installets that work on that operating system, for example `simple_lamp_server.sh` and optionally another file called `simple_lamp_server-clean.sh` (ending with `-clean.sh`) that will undo/uninstall everything (or as much as possible) what the previous script did.
