Name: dzhakishev-todo
Version: 1.0
Release: alt1

Summary: To-do list shell script with dialog interface (lab 4)
License: GPL-2.0-or-later
Group: Office
BuildArch: noarch

Source0: dzh-todo

%description
dzh-todo keeps a to-do list in the user configuration directory.
Without arguments it shows a menu built with dialog; the commands
"add TEXT", "list" and "done N" work without the dialog interface.
Laboratory work 4, Dzhakishev A.M., group KT-22-04.

%install
install -D -m 0755 %SOURCE0 %buildroot%_bindir/dzh-todo

%files
%_bindir/dzh-todo

%changelog
* Mon Nov 09 2026 Amir Dzhakishev <dzhakishev@altlinux.org> 1.0-alt1
- Initial build
