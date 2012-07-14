# heroku-anvil

CLI plugin for [anvil](https://github.com/ddollar/anvil)

## Installation

    $ heroku plugins:install https://github.com/ddollar/heroku-anvil

## Usage

#### Create a slug

	$ heroku build
	Generating app manifest... done
	Uploading new files... done, 0 files needed
	Launching build process... done
	Recreating app from manifest... done
	Fetching buildpack... done
	Detecting buildpack... done, Buildkit+Node.js
	Compiling app...
	  Compiling for Node.js
	  ...
	Creating slug... done
	Uploading slug... done
	Success, slug is https://anvil-production.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img

#### Create a slug and release it

	$ heroku build -r
	Generating app manifest... done
	Uploading new files... done, 0 files needed
	Launching build process... done
	Recreating app from manifest... done
	Fetching buildpack... done
	Detecting buildpack... done, Buildkit+Node.js
	Compiling app...
	  Compiling for Node.js
	  ...
	Creating slug... done
	Uploading slug... done
	Success, slug is https://anvil-production.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img
	Downloading slug... done
	Releasing to anvil... done, v158

#### Release an existing slug

	$ heroku release https://anvil-production.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img
	Downloading slug... done
	Releasing to anvil... done, v158

## Advanced Usage

#### Build

	Usage: heroku build [DIR]

	 deploy code

	 -b, --buildpack URL  # use a custom buildpack
	 -e, --runtime-env    # use runtime environment during build
	 -r, --release        # release the slug to an app

#### Release

	Usage: heroku release SLUG_URL

	  release a slug
