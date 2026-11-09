Name: dzhakishev-args
Version: 1.0
Release: alt1

Summary: Print command line arguments: static and shared library variants (lab 3)
License: GPL-2.0-or-later
Group: Development/Other

Source: %name-%version.tar.gz

%description
Multi-file project for laboratory work 3 (Dzhakishev A.M., group KT-22-04).
The package contains two programs that print their command line
arguments: dzhargs-static is linked with the static library libdzhargs.a,
dzhargs-shared uses the shared library libdzhargs.so.1 from this package.

%prep
%setup

%build
%make_build CFLAGS="%optflags"

%install
install -D -m 0755 dzhargs-static %buildroot%_bindir/dzhargs-static
install -D -m 0755 dzhargs-shared %buildroot%_bindir/dzhargs-shared
install -D -m 0755 libdzhargs.so.1 %buildroot%_libdir/libdzhargs.so.1

%files
%_bindir/dzhargs-static
%_bindir/dzhargs-shared
%_libdir/libdzhargs.so.1

%changelog
* Mon Nov 09 2026 Amir Dzhakishev <dzhakishev@altlinux.org> 1.0-alt1
- Initial build
