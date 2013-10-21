# heroku-anvil

Alternate Heroku build process.

## Installation

    $ heroku plugins:install https://github.com/ddollar/heroku-anvil

## Usage

#### Compile an application from a local directory and release it to Heroku

    $ heroku build -r myapp
    Building ...
    Success, slug is https://api.anvilworks.org/slugs/000.tgz
    Releasing to myapp.heroku.com... done, v42

#### Release a slug to another app

    $ heroku release https://api.anvilworks.org/slugs/000.tgz -a myapp-staging
    Releasing to myapp-staging.heroku.com... done, v42
    
#### Alternatively, you can build from a public-accessible git repository

    $ heroku build https://github.com/ddollar/anvil.git
    
#### You can also specify a buildpack

    # specify a buildpack url
    $ heroku build https://github.com/ddollar/anvil.git -b https://github.com/heroku/heroku-buildpack-nodejs.git
    
    # specify a buildpack from https://buildkits.heroku.com/
    $ heroku build https://github.com/ddollar/anvil.git -b heroku/nodejs

#### Use a gist as a buildpack

    # build mercurial
    $ heroku build http://mercurial.selenic.com/release/mercurial-2.7.1.tar.gz -b https://gist.github.com/ddollar/07d579a6621b3ddd7b6b/raw/gistfile1.txt
    
#### Use the pipelining feature to build complex deploy workflows

    #!/usr/bin/env bash
    
    # fail fast
    set -o errexit
    set -o pipefail
    
    # compile a slug of the app
    slug=$(heroku build https://github.com/my/project.git -p)

    # release the slug to staging
    heroku release $slug -a myapp-staging
    
    # run tests using `heroku run`
    heroku run bin/tests -a myapp-staging
    
    # test that the app responds via http
    curl https://myapp-staging.herokuapp.com/test
    
    # release to production
    heroku release $slug -a myapp-production

## Advanced Usage

#### heroku build

    Usage: heroku build [SOURCE]

     build software on an anvil build server

     if SOURCE is a local directory, the contents of the directory will be built
     if SOURCE is a git URL, the contents of the repo will be built
     if SOURCE is a tarball URL, the contents of the tarball will be built

     SOURCE will default to "."

     -b, --buildpack URL  # use a custom buildpack
     -p, --pipeline       # pipe compile output to stderr and only put the slug url on stdout
     -r, --release        # release the slug to an app

#### heroku release

    Usage: heroku release SLUG_URL

     release a slug

     -p, --procfile PROCFILE  # use an alternate Procfile to define process types
