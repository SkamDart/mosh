/* config.h - Minimal configuration for Zig build */
/* This file replaces the autoconf-generated config.h */

#ifndef CONFIG_H
#define CONFIG_H

/* Package information */
#define PACKAGE_VERSION "1.4.0"
#define PACKAGE_STRING "mosh 1.4.0"
#define PACKAGE_NAME "mosh"
#define PACKAGE_TARNAME "mosh"
#define PACKAGE_BUGREPORT "mosh-devel@mit.edu"
#define PACKAGE_URL "https://mosh.org"

/* System features */
#define HAVE_FORKPTY 1
#define HAVE_CFMAKERAW 1
#define HAVE_CLOCK_GETTIME 1
#define HAVE_DECL_FORKPTY 1

/* Crypto backend - using OpenSSL by default */
#define USE_OPENSSL_AES 1

/* Platform-specific definitions */
#ifdef __APPLE__
  #define HAVE_UTIL_H 1
  #define HAVE_LIBUTIL 1
#else
  #define FORKPTY_IN_LIBUTIL 1
  #define HAVE_PTY_H 1
  #define HAVE_SYS_STROPTS_H 1
#endif

/* Standard headers */
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_UNISTD_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_IOCTL_H 1
#define HAVE_SYS_SELECT_H 1
#define HAVE_SYS_TIME_H 1

/* Network features */
#define HAVE_PSELECT 1
#define HAVE_GETADDRINFO 1
#define HAVE_GETNAMEINFO 1

/* Time functions */
#define HAVE_GETTIMEOFDAY 1

/* Terminal features */
#define HAVE_IUTF8 1
#define HAVE_NCURSES_H 1

/* Locale features */
#define HAVE_LANGINFO_H 1
#define HAVE_NL_LANGINFO 1

/* C++ features */
#define HAVE_STD_SHARED_PTR 1

/* Define to 1 if you have the <utempter.h> header file. */
#ifdef __linux__
  #define HAVE_UTEMPTER 1
  #define HAVE_UTEMPTER_H 1
#endif

#endif /* CONFIG_H */
