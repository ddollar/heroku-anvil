# heroku-anvil

CLI plugin for [anvil](https://github.com/ddollar/anvil)

## Installation

    $ heroku plugins:install https://github.com/ddollar/heroku-anvil

## Usage

#### Create a slug

	# create a
	$ cd myapp; heroku push
	Generating application manifest... done
	Computing diff for upload... done
	Uploading new files... done
	Compiling...
	Launching build slave
	Buildpack: Buildkit+Node.js
	-----> Compiling for Node.js
	...
	Success, slug is https://anvil.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img

#### Create a slug and release it

	$ heroku push -r
	Generating application manifest... done
	Computing diff for upload... done
	Uploading new files... done
	Compiling...
	Launching build slave
	Buildpack: Buildkit+Node.js
	-----> Compiling for Node.js
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
