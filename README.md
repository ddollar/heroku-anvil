# heroku-anvil

Heroku CLI integration with an [Anvil](https://github.com/ddollar/anvil) build server.

## Installation

    $ heroku plugins:install https://github.com/ddollar/heroku-anvil

## Usage

#### Build a local directory

    $ heroku build

#### Build a local directory with a specific buildpack
    $ heroku build -b nodejs
    $ heroku build -b https://github.com/heroku/heroku-buildpack-nodejs.git#master

#### Build a git repository

    $ heroku build https://github.com/ddollar/anvil.git

#### Use `-p` to create pipelines

    $ slug=$(heroku build . -p) 2>/tmp/log/build.log
    $ heroku release $slug

#### Build a tarball using a shell script as a buildpack

    $ heroku build http://memcached.googlecode.com/files/memcached-1.4.13.tar.gz \
                -b https://raw.github.com/ddollar/vulcan-recipes/master/memcached.sh

#### Release to Heroku after building

    $ heroku build -r -a myapp
    ...
    Releasing to myapp... done, v42

#### Release already-built software

    $ heroku release $slug_url -a myapp
    Releasing to myapp... done, v42

## Advanced Usage

#### heroku build

    $ heroku help build
    Usage: heroku build [SOURCE]

     build software on an anvil build server

     if SOURCE is a local directory, the contents of the directory will be built
     if SOURCE is a git URL, the contents of the repo will be built

     SOURCE will default to "."

     -b, --buildpack URL  # use a custom buildpack
     -e, --runtime-env    # use an app's runtime environment during build
     -p, --pipeline       # pipe compile output to stderr and only put the slug url on stdout
     -r, --release        # release the slug to an app

#### heroku release

    Usage: heroku release SLUG_URL

     release a slug

     -p, --procfile PROCFILE  # use an alternate Procfile to define process types
