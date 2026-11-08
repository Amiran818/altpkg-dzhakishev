Name: dzhakishev-show
Version: 1.0
Release: alt1

Summary: Simple ncurses text file pager (lab 2, Dzhakishev A.M.)
License: GPL-2.0-or-later
Group: Text tools

Source: %name-%version.tar.gz

BuildRequires: libncurses-devel

%description
Show displays a text file page by page using the ncurses library.
Space scrolls one page forward, q quits. Laboratory work 2,
Dzhakishev A.M., group KT-22-04.

%prep
%setup

%build
%make_build CFLAGS="%optflags"

%install
install -D -m 0755 Show %buildroot%_bindir/Show

%files
%_bindir/Show

%changelog
* Mon Nov 09 2026 Amir Dzhakishev <dzhakishev@altlinux.org> 1.0-alt1
- Initial build
