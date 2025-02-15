Network Security Services for Java (JSS)
========================================

Overview
--------

**Network Security Services for Java** is a Java interface to [NSS](https://developer.mozilla.org/en-US/docs/Mozilla/Projects/NSS).
JSS supports most of the security standards and encryption technologies supported by NSS.
JSS also provides a pure Java interface for ASN.1 types and BER/DER encoding.

* Website: http://www.dogtagpki.org/wiki/JSS
* Issues: https://github.com/dogtagpki/jss/issues
* Archive: https://github.com/dogtagpki/jss-archive
* Javadocs: https://dogtagpki.github.io/jss

**NOTICE:** As of JSS version 4.5.1, the legacy build instructions will not
            work; the build system has been completely replaced with CMake.

Dependencies
------------

This project has the following dependencies:

 - [NSPR](https://developer.mozilla.org/en-US/docs/Mozilla/Projects/NSPR)
 - [NSS](https://developer.mozilla.org/en-US/docs/Mozilla/Projects/NSS)
    - Minimum version: 3.44
    - Recommended version: 3.48 and above
    - A c and c++ compiler such as [gcc](ttps://gcc.gnu.org/)
    - [zlib](https://zlib.net/)
 - [OpenJDK 1.8.0 or newer](https://openjdk.java.net/)
 - [CMake](https://cmake.org/)
 - [Apache Commons Lang](https://commons.apache.org/proper/commons-lang/)
 - [SLF4J](https://www.slf4j.org/)
 - [JUnit 4](https://junit.org/junit4/)

To install these dependencies on Fedora, execute the following:

    sudo dnf install apache-commons-lang gcc-c++ java-devel jpackage-utils \
                     slf4j zlib-devel nss-tools nss-devel \
                     cmake junit

To install these dependencies on Debian, execute the following:

    sudo apt-get install build-essential libcommons-lang-java libnss3-dev \
                         libslf4j-java default-jdk pkg-config zlib1g-dev \
                         libnss3-tools cmake zip unzip \
                         junit4


Building
--------

To build JSS and make a best effort to detect environment variables:

    git clone https://github.com/dogtagpki/jss
    cd jss/build && cmake ..
    make all test

Alternatively, to build a RPM distribution of JSS:

    git clone https://github.com/dogtagpki/jss
    cd jss
    ./build.sh rpm

To view more detailed instructions for building JSS, please refer to
the build documentation: [`docs/building.md`](docs/building.md).


In Distributions
----------------

JSS is currently shipped in Fedora-based distributions under the package
name `jss`; to install issue `sudo dnf install jss`.

JSS is also shipped in Debian-based distributions under the package
name `libjss-java`; to install, issue `sudo apt-get install libjss-java`.


Contact Us
----------

See [Contact Us](https://github.com/dogtagpki/pki/wiki/Contact-Us).
