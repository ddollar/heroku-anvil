# anvil

Builds as a service.

## Installation

    $ gem install anvil-cli

## Usage

#### Build an application from a local directory

    $ anvil build .
    Building ...
    Success, slug is https://api.anvilworks.org/slugs/000.tgz

#### Build from a public-accessible git repository

    $ anvil build https://github.com/ddollar/anvil.git
    
#### Specify a buildpack

    # specify a buildpack url
    $ anvil build https://github.com/ddollar/anvil.git -b https://github.com/heroku/heroku-buildpack-nodejs.git
    
    # specify a buildpack from https://buildkits.heroku.com/
    $ anvil build https://github.com/ddollar/anvil.git -b heroku/nodejs
    
#### Iterate on buildpacks without pushing to Github

    # test a known app against the local buildpack code
    $ anvil build https://github.com/me/mybuildpack-testapp -b ~/mybuildpack
    
    # can also use a local app
    $ anvil build ~/mybuildpack/test/app -b ~/mybuildpack
    
#### Build using a shell script from a URL

You can use this combination to host build scripts in gists. [Example](https://gist.github.com/ddollar/a2ceb7b9699f05303170)

    $ anvil build \
      http://downloads.sourceforge.net/project/squashfs/squashfs/squashfs4.2/squashfs4.2.tar.gz \
      -b https://gist.github.com/ddollar/a2ceb7b9699f05303170/raw/build-squashfs.sh

#### Use the pipelining feature to build complex deploy workflows

This example requires the [heroku-anvil](https://github.com/ddollar/heroku-anvil) plugin.

    #!/usr/bin/env bash
    
    # fail fast
    set -o errexit
    set -o pipefail
    
    # build a slug of the app
    slug=$(anvil build https://github.com/my/project.git -p)

    # release the slug to staging
    heroku release $slug -a myapp-staging
    
    # run tests using `heroku run`
    heroku run bin/tests -a myapp-staging
    
    # test that the app responds via http
    curl https://myapp-staging.herokuapp.com/test
    
    # release to production
    heroku release $slug -a myapp-production

## Advanced Usage

#### anvil build

    Usage: anvil build [SOURCE]

     build software on an anvil build server

     if SOURCE is a local directory, the contents of the directory will be built
     if SOURCE is a git URL, the contents of the repo will be built
     if SOURCE is a tarball URL, the contents of the tarball will be built

     SOURCE will default to "."

     -b, --buildpack URL  # use a custom buildpack
     -p, --pipeline       # pipe build output to stderr and only put the slug url on stdout
     -r, --release        # release the slug to an app
