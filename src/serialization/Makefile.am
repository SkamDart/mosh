AM_CPPFLAGS = -I$(top_srcdir)/
AM_CXXFLAGS = $(WARNING_CXXFLAGS) $(HARDEN_CFLAGS) $(MISC_CXXFLAGS) $(CODE_COVERAGE_CXXFLAGS)

noinst_LIBRARIES = libmoshserialization.a

# Dummy C++ file to satisfy automake
libmoshserialization_a_SOURCES = serialization_stub.cc

# Install the header for other modules to use
noinst_HEADERS = mosh_serialization.h

# Custom rule to build Zig library and copy it
all-local: zig-library

zig-library: build.zig src/c_api.zig src/serialization.zig src/messages/user_message.zig src/messages/host_message.zig src/messages/transport_instruction.zig
	cd $(srcdir) && $(ZIG) build -Doptimize=ReleaseFast
	cp $(srcdir)/zig-out/lib/libmosh_serialization.a libmoshserialization.a

CLEANFILES = libmoshserialization.a

# Run Zig tests
check-local:
	cd $(srcdir) && $(ZIG) build test

.PHONY: check-local zig-library