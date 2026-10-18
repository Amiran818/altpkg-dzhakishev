Name: dzhakishev-hello
Version: 1.0
Release: alt1

Summary: Prints student name, group and lab number
License: GPL-2.0-or-later
Group: Development/Other

Source0: %name.sh

BuildArch: noarch

%description
Shell script that prints the student surname, group number
and the number of the laboratory work (Dzhakishev A.M., KT-22-04).

%install
install -D -m 0755 %SOURCE0 %buildroot%_bindir/%name

%files
%_bindir/%name

%changelog
* Mon Oct 19 2026 Amir Dzhakishev <344528613+Amiran818@users.noreply.github.com> 1.0-alt1
- Initial build
