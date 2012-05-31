# heroku-anvil

CLI plugin for [anvil](https://github.com/ddollar/anvil)

## Installation

    $ heroku plugins:install https://github.com/ddollar/heroku-anvil

## Usage

#### Create a slug

	$ cd myapp; heroku push
	Generating app manifest... done
	Computing diff for upload... done, 2 files needed
	Uploading new files... done
	Launching build process... done
	Recreating app from manifest...  done
	Fetching buildpack...  done
	Detecting buildpack...  done, Buildkit+Node.js
	Compiling app...
	  Compiling for Node.js
	  ...
	Success, slug is https://anvil.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img

#### Create a slug and release it

	$ heroku push -r
	Generating app manifest... done
	Computing diff for upload... done, 2 files needed
	Uploading new files... done
	Launching build process... done
	Recreating app from manifest...  done
	Fetching buildpack...  done
	Detecting buildpack...  done, Buildkit+Node.js
	Compiling app...
	  Compiling for Node.js
	  ...
	Success, slug is https://anvil.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img
	Downloading slug... done
	Uploading slug for release... done
	Releasing to myapp... done, v30

#### Release an existing slug

	$ heroku release https://anvil.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img
	Downloading slug... done
	Uploading slug for release... done
	Releasing to myapp... done, v31

## Advanced Usage

	Usage: heroku push [DIR]

	 deploy code

	 -b, --buildpack URL  # use a custom buildpack
	 -e, --runtime-env    # use runtime environment during build
	 -r, --release        # release the slug to an app
