[![Build Status](https://travis-ci.org/simpleviewinc/mongolayer.svg?branch=master)](https://travis-ci.org/simpleviewinc/mongolayer)

# mongolayer

`npm install mongolayer`

Mongolayer is a rich document system similar to Mongoose, but thinner, more type-strict, and with more developer flexibility.

This module is an attempt at providing the vision of `mongoose` (validation, hooks, relationships) but with less eccentricities, less magic under the hood providing developers with more consistent behaviors.

# Changelog

## 3/11/2020 - 2.0.0
- Adds support for `Model` based on a mongodb view.
- `createIndexes` parameter of `connection.add` is deprecated, please use `sync` instead.

## 9/3/2019 - 1.5.8
- Adds `options.context` for passing state to all descendent hooks. Needed for handling conditions where variables need to be available in the top level hook, and in the nested relationship hooks.

## 7/19/2019 - 1.5.7
- Adds `Connection.promises.add`, `mongolayer.promises.connect`, `mongolayer.promises.connectCached`.

## 5/16/2019 - 1.5.2
- Adds back the `promises` object to maintain consistency with the Node core strategy of exposing `promises` object. Adds support for all async methods on the `Model`.

## 5/14/2019 - 1.5
- Updates to mongodb 3.2.4
- `find`, `findById`, `aggregate` updated so that if you execute them without passing a callback they will now return a promise, allowing them to executed via await.
- Removes the `promises` object, it's better when we can utilize the methods without the verbosity of having to go to `promises.method`.

## 7/21/2017 - 1.4
- Virtuals have become a whole smarter. You can now specify a virtual field as having requiredFields and requiredHooks. If you reference that field in a find() fields obj, it will automatically include the requiredFields and hooks. This makes working with relationships and virtuals much simpler.
- Relationships can now be executed simply by adding the field to your fields obj, without needing to ask for dependent keys and the hook. See Populating Relationships for more info.
- find() `options.castDocs === false` behavior has changed. If it's specified, and a truthy fields obj is passed, it will *only* return the specified fields. This differs from native mongodb, which will continue to return _id even if it's not asked for. This makes the downstream from queries simpler to work with as you only receive what you ask for. Nested empty `{}` and `[]` will always be trimmed from the final result. See castDocs in find() for more information.
- find() `options.castDocs === false` and passing fields is the recommended default behavior for all queries where performance matters as it forces you to specify only the fields you want.
- BREAKING - Virtuals can no longer be referenced in hooks. This is for capability when working with `castDocs === false` and `castDocs === true`. In general if you need data created via a virtual inside a hook, you should be creating that data with a hook instead.
- Aggregate now supports hooks, `beforeAggregate` and `afterAggregate`
- Aggregate now supports `options.castDocs` and `options.virtuals` for utilizing virtuals when returning data via aggregate
- Fixed potential RSS memory expansion issue due to usage of `WeakMap()`.
- BREAKING - When specifying a fields object you will only receive those fields. Previously if you requested { "relationship.foo" : 1 }, you would still get all keys on the root (since foo is on a relationship). This is no longer the case. This change was made so it more closely mimics native MongoDB which only returns the fields that are requested.
- find() `options.castDocs === false` is now recursive through relationships. When specified all relationships will also be pulled with castDocs === false. This means if you need to access virtuals on them, you should specify them via the fields obj.

# Documentation

* [Hooks](#hooks)
	* [Hook Arguments](#hook-arguments)
	* [Hook Examples](#hook-examples)
		* [blogPost beforeFilter](#blogpost-beforefilter)
	* [Calling Hooks](#calling-hooks)
	* [Runtime Hooks](#runtime-hooks)
	* [Default Hooks](#default-hooks)
* [Relationships](#relationships)
	* [Setting Data](#setting-data)
	* [Populating Relationships](#populating-relationships)
* [API Documentation](#api-documentation)
	* [mongolayer](#api-documentation)
	* [Connection](#connection)
	* [Model](#model)
		* [Querying](#querying)
		* [Properties](#model-properties)

# Features
1. Supports the basic queries: `find`, `findById`, `save`, `update`, `count`, and `remove`.
1. Infinitely recursive field validation on `insert`, `save`, and `update`. Allowing you to validate arrays, objects, and any recursive combination of them.
1. Enforce required fields and field defaults on `insert`, `save` and `update`.
1. Robust hook system to run async code before and after any query. You can set default hooks, required hooks, and specify which hooks run at query time.
1. Declare relationships between models allowing infinite recursive population of related records. Related records will be pulled with virtuals and methods.
1. Getter and setter virtuals on the document level.
1. Methods on the document level.
1. Methods on the model level.

# Why not just use Mongoose?

`mongoose` is a powerful package to which this module owes great homage, but after using `mongoose` for a while I became frustrated with some of it's eccentricities. In attempting to contribute to the module it became clear that the codebase was quite burdened by legacy.

Here are some examples of frustrations I personally came across using `mongoose`.

1. If a record in the DB does not have a value in a field, it will still fill that field with a default value when you pull it out of the database. This gives the illusion a value exists in the db, when it doesn't.
1. Unable to recursive populate recursive records (populate in a populate). You can only populate one level deep.
1. When records are populated, they are plain objects, lacking virtuals and methods that they would have if acquired with a normal query.
1. Unable to run post-query hooks with async code that gets flow control.
1. Too many differences from the way that node-mongodb-native and mongodb function out of the box. In example, `mongoose` wraps `update` with `$set` causing queries that 'look' correct in mongodb shell and node-mongodb-native to perform entirelly different. Mongoose calls it `create` while node-mongodb-native and mongodb shell call it `insert`.
1. Update method doesn't run hooks, or validation.
1. `save` method not implemented with unless using the new doc() syntax. So `find`, `create`, all use one syntax, but `save` uses an entirely different syntax.
1. Each document in mongoose is an instance of the Schema. That just doesn't make sense to me. The fields on my Document should only be the fields I add, nothing more, nothing less.

# Getting Started

`npm install mongolayer`

Mongolayer has three basic constructs, **Models**, **Connections** and **Documents**.

* `mongolayer.Connection` - Manage the connection pool and the raw connection to MongoDB. The connection is aware of all of the Models that are attached to it.
* `mongolayer.Model` - The bread-and-butter of mongolayer, your queries are executed on Models and they have fields, methods, and a ton of other features. These are attached to Connections.
* `mongolayer.Document` - Base document class for all documents. 
* `model.Document` - After running a query, each row from the database is returned as an `instanceof` the `model.Document` class specific to the model.

Basic application boot-up

1. Create connection.
1. Create models.
1. Attach models to connection.
1. Run queries, and return documents.

```js
var mongolayer = require("mongolayer");

// create a model
var postModel = new mongolayer.Model({
	collection : "posts",
	fields : [
		{ name : "title", validation : { type : "string" }, required : true },
		{ name : "description", validation : { type : "string" }, required : true }
	]
});

// get a mongolayer connection
mongolayer.connectCached({ connectionString : "mongodb://127.0.0.1:27017/mongoLayer" }, function(err, conn) {
	// attach a model to a connection
	conn.add({ model : postModel }, function(err) {
		// once a model is attached to a connection, assuming no errors, you can then run queries on the model
		
		// you can run queries by using the model reference
		postModel.find({}, function(err, docs) {
			// do something
		});
		
		// you can run queries by using the connection reference
		conn.models.posts.find({}, function(err, docs) {
			// do something
		});
		
		// whether you pass around the model references or the connection is totally up to your application architecture!
	});
});
```

# Views

Creates a view and exposes it via the model. `viewOn` and `pipeline` pass directly to https://docs.mongodb.com/manual/reference/command/create/.

```js
const model = new mongolayer.Model({
	collection : "testing",
	viewOn : "name_of_model",
	pipeline : []
});
```

Once a view is added to a connection you can query on it with `find`, `aggregate`, `count` and all of the various content querying methods.

# Hooks

Hooks are the powerful underpining that makes relationship management possible, in addition they provide an entry point for developers to run async code before or after all major qureies, allowing them to maintain a coherent object model. Every major query function invokes a number of different hooks.

Here are some common uses for hooks:

* Specify a `beforeFilter` hook which will run prior to `count`, `remove`, `find` allowing you to transform the filter, such as casting a string to a `mongolayer.ObjectId`.
* Specify an `afterFind` hook which would log some information to a log file based on the number of records returned.
* Specify a `afterRemove` hook to remove related orphan records.
* Specify an `afterFind` hook to pull in other data which is not stored in mongoDB and can't be managed through relationships such as Facebook posts, SQL data, file system data, or memcache data.
* Specify a `beforePut` hook which will do some async data management such as encrypting a password prior to storing in the DB.

Query functions which support hooks: `find`, `findById` (runs same hooks as `find`), `count`, `remove`, `insert`, `save`, `update`.

For specific rules of which hooks are executed by which query see the API documentation for that query.

Important: Hooks do not have access to data created by virtuals! Often hooks are used to populate data needed by virtuals. If you need virtual data in a hook, the recommendation is to utilize the virtual system to declare a writable virtual which is populated via a requiredHook. If both hooks are invoked via virtuals then the dependency system is managed automatically without needing to understand it at query time.

## Declaring Hooks

All hooks are specified as a function which recieves an arguments object and a callback. All hooks are expected to callback with either an error or the args they received.

It is highly recommended, but not required, that all hooks are declared before attaching it to a `mongolayer.Connection`.

```js
// add a hook to a model
model.addHook({
	name : "foo",
	type : "afterFind",
	handler : function(args, cb) {
		// if you want the hook to "fail" and prevent any further hooks or actions from running, callback an error
		return cb(new Error("something something"));
		
		// if you want the hook to succeed and continue, callback with args
		return cb(null, args);
	}
});

// define a model with hooks
var model = new mongolayer.Model({
	collection : "foo",
	hooks : [
		{
			name : "foo",
			type : "afterFind",
			handler : function(args, cb) {
				// if you want the hook to "fail" and prevent any further hooks or actions from running, callback an error
				return cb(new Error("something something"));
				
				// if you want the hook to succeed and continue, callback with args
				return cb(null, args);
			}
		}
	]
});
```

## Hook Arguments

The arguments a hook receives will differ based on the specific hook. The following describes which arguments each hook will receive.

### beforeAggregate(args, cb)

* `args.pipeline` - `array` - The aggregation pipeline
* `args.options` - `object` - Options passed to the aggregate call

### afterAggregate(args, cb)

* `args.pipeline` - `array` - The aggregation pipeline
* `args.options` - `object` - Options passed to the aggregate call
* `args.docs` - `array` - Array of documents returned from the aggregate call

### beforeFind(args, cb)

* `args.filter` - `object` - The filter passed in to the query.
* `args.options` - `object` - The options object passed in to the query.

### afterFind(args, cb)

* `args.filter` - `object` - The filter passed in to the query.
* `args.options` - `object` - The options passed in to the query.
* `args.docs` - `array` - An array of `model.Document`. Modify the contents of this array if you want to fold in or alter data in your hook.

### beforeInsert(args, cb)

* `args.docs` - `array` - Array of whatever was passed in to insert (could be simple JS objects, or `model.Document`). Even if a query is passing a single document, it will be an array.
* `args.options` - `object` - The options argument of the insert statement.

### afterInsert(args, cb)

* `args.docs` - `array` - Array of `model.Document`. It will always be an array of documents even if a query is passing a single document.
* `args.options` - `object` - The options argument of the insert statement.
* `args.result` - `object` - The mongoDB writeResult.

### beforeSave(args, cb)

* `args.doc` - `object` or `model.Document` - Simple JS object or `model.Document`
* `args.options` - `object` - The options argument of the save statement.

### afterSave(args, cb)

* `args.doc` - `model.Document` - Document that was inserted.
* `args.options` - `object` - The options argument of the insert statement.
* `args.result` - `object` - The MongoDB writeResult.

### beforeCount(args, cb)

* `args.filter` - `object` - The filter passed in to the query.
* `args.options` - `object` - The options object passed in to the query.

### afterCount(args, cb)

* `args.filter` - `object` - The filter passed in to the query.
* `args.options` - `object` - The options object passed in to the query.
* `args.count` - `number` - The number of records found.

### beforeUpdate(args, cb)

* `args.filter` - `object` - The filter passed in to the query.
* `args.delta` - `object` - The changes which will be passed to the DB.
* `args.options` - `object` - The options object passed in to the query.

### afterUpdate(args, cb)

* `args.filter` - `object` - The filter passed in to the query.
* `args.delta` - `object` - The changes which will be passed to the DB.
* `args.options` - `object` - The options object passed in to the query.
* `args.result` - `object` - The mongoDB writeResult.

### beforeRemove(args, cb)

* `args.filter` - `object` - The filter passed in to the query.
* `args.options` - `object` - The options object passed in to the query.

### afterRemove(args, cb)

* `args.filter` - `object` - The filter passed in to the query.
* `args.options` - `object` - The options object passed in to the query.
* `args.result` - `object` - The mongoDB writeResult.

### beforeFilter(args, cb)

`beforeFilter` is called by `find`, `update`, `remove` and `count`. Use it for transforming the filter in a global sense.

* `args.filter` - `object` - The filter passed in to the query.
* `args.options` - `object` - The options object passed in to the query.

### beforePut(args, cb)

`beforePut` is called by `insert`, and `save` prior to inserting a new record or fully overwriting and existing record.

Due to technical eccentricities `beforePut` cannot be called on `update`, even when using `upsert : true` in your options. If you want to fully replace a record with upsert semantics use `save`.

* `args.doc` - `object` - Simple JS object or `model.Document` to be inserted or overwrite an existing record.
* `args.options` - `object` - The options object passed in to the query.

### afterPut(args, cb)

`afterPut` is called on `insert`, and `save` after inserting a new record or fully overwriting an existing record. If you need to run code to create related entries this is a good hook to accomplish that task.

Due to technical eccentricities `afterPut` cannot be called on `update`, even when using `upsert : true` in your options. If you want to fully replace a record with upsert semantics use `save`.

* `args.doc` - `model.Document` - The document that was placed into the database.
* `args.options` - `object` - The options object passed in to the query.

## Hook Examples

### blogPost beforeFilter

Imagine you have the following Model for a blog post.

```js
var model = new mongolayer.Model({
	collection : "posts",
	fields : [
		{ name : "title", validation : { type : "string" }, required : true },
		{ name : "description", validation : { type : "string" }, required : true },
		{ name : "published", validation : { type : "boolean" }, default : true },
		{ name : "startdate", validation : { type : "date" }, required : true, default : function() { return new Date() } },
		{ name : "enddate", validation : { type : "date" } } // note: enddate is not required
	]
});
```

In this model we have a published boolean as well as startdate and enddate. This allows the user to publish a post, but also specify the date it will show up on the site (defaulting to now), and they can specify an optional enddate where the post will no longer appear on the site. If no enddate is supplied it will always be on the site.

Now, if a developer wants to get all posts which are "active", meaning that they are published and today's date is between their startdate and enddates (if the post has them), the developer would perform the following query.

```js
model.find({
	published : true,
	startdate : { $lte : new Date() },
	$or : [{ enddate : { $gt : new Date() } }, { enddate : { $exists : false } }]
}, function(err, docs) {
	// do stuff
});
```

Let's simplify this, using the hook system we can create a beforeFilter hook which will make getting "active" posts much, much simpler.

```js
model.addHook({
	name : "activeFilter",
	type : "beforeFilter",
	required : true,
	handler : function(args, cb) {
		if (args.filter.active === true) {
			// take developers passed filter and $and it with our "active" abstract filter
			var currentFilter = args.filter;
			delete args.filter.active;
			args.filter = {
				$and : [
					{
						published : true,
						startdate : { $lte : new Date() },
						$or : [{ enddate : { $gt : new Date() } }, { enddate : { $exists : false } }]
					},
					currentFilter
				]
			}
		}
		
		return cb(null, args);
	}
});
```

Now if I want to get all active posts I simply can run.

```js
model.find({
	active : true
}, function(err, docs) {
	// do stuff
});
```

Also, I could query for everything which is "active" and has a description containing the word 'mongolayer'.

```js
model.find({
	active : true,
	description : { $regex : ".*mongolayer.*" }
}, function(err, docs) {
	// do stuff
})
```

It is important to note that this same "active" concept applies to all queries which run the beforeFilter hook such as update(), remove(), and count().

```js
model.count({
	active : true
}, function(err, count) {
	// do stuff
});
```

Using this, we've abstracted the concept of "active" so that other developers don't have to deal with the complexity behind it. This reduces code repetition and the possibility for developer errors downstream.

## Calling Hooks

You can choose to execute these hooks always, by default, or at run-time.

### Required Hooks

Here is an example of a required hook which will convert a id string to a mongolayer objectid. Any query which executes the beforeFilter hooks will execute this hook because it has `required : true` in it's definition.

```js
model.addHook({
	name : "idCast",
	type : "beforeFilter",
	handler : function(args, cb) {
		if (args.filter.id !== undefined) {
			args.filter._id = new mongolayer.ObjectId(args.filter.id);
			delete args.filter.id;
		}
		
		cb(null, args);
	},
	required : true
});
```

### Runtime Hooks

Hook sets are specified by passing an `array` of `string` or an `array` of `object` with a specific naming scheme.

**Note**: Default hooks are never run when specifying a `hooks` array at run-time.

```js
// this will execute the 'beforeFilter' hook named 'idCast' in addition to any other hooks which are required
// default hooks are never run when specifying hooks are run-time
model.find({ foo : "bar" }, { hooks : ["beforeFilter_idCast"] }, function(err, docs) {
	
});

// this will execute the 'beforeFilter' hook named 'idCast' and the 'afterFind' hook named 'getExtraData'
model.find({ foo : "bar" }, { hooks : ["beforeFilter_idCast", "afterFind_getExtraData"] }, function(err, docs) {
	
});
```

When using relationships, you can also specify hooks to run on related models.  These nested hooks can be infinitely recursive.

In the event no hooks are passed to a related model, that model will still execute it's default hooks.

```js
// this will execute the 'beforeFilter' hook named 'idCast' and the 'afterFind' hook named 'authors' on our primary model
// it will also execute the 'afterFind' hook named 'getImage' on our authors model
model.find({ foo : "bar" }, { hooks : ["beforeFilter_idCast", "afterFind_authors", "authors.afterFind_getImage"] }, function(err, docs) {
	
});
```

You can also pass arguments to hooks at runtime if your hook requires it.

```js
model.addHook({
	name : "getExtraData",
	type : "afterFind",
	handler : function(args, cb) {
		// args.hookArgs.foo === "bar"
		
		cb(null, args);
	}
});

// The 'afterFind' hook named 'getExtraData' will receive 'hookArgs' key containing the args passed here
// using the hook declared above you can see how it receives the args
model.find({ foo : "bar" }, { hooks : [{ name : "afterFind_getExtraData", args : { foo : "bar" } }] }, function(err, docs) {

});
```

### Default Hooks

Default hooks allow you to specify an `array` of hooks to run when a query is called an no hooks are passed.

The syntax for the hook `array` is identical to what you would pass at query time outlined in the above section.

**Note**: If any hooks are passed at runtime, then default hooks will not be passed. Required hooks will execute regardless of whether hooks are passed at runtime or by default.

```js
// the syntax of the array is identical to declaring them at runtime
// the name of the defaultHook key is the same as query operation so 'find', 'update', 'count', 'remove', 'insert', and 'save'
var model = new mongolayer.Model({
	defaultHooks : {
		find : ["afterFind_getExtraData"]
	}
});

var model = new mongolayer.Model({
	defaultHooks : {
		update : ["beforeFilter_foo"],
		remove : ["beforeFilter_foo"],
		insert : ["beforePut_bar", "afterInsert_baz"]
	}
});
```

# Relationships

Managing relationships is a key functionality of mongolayer. Relationships are primarily used to connect records together. Like mongoose, it provides a way to pull in related records. Unlike mongoose, it provides that capability recursively.

In example, a blog post may have an author which is managed in another table. When you query for blog posts, you may want that author record pulled in as well. That author may also have relationships of their own which you want pulled down as well.

Key Points:

* All relationships should always be unidirectional. If a blogPost has an author, then one side of that relationships stores the state (for example an author_id field in the blogPost model).
	* Cross-table based relationships are not possible to maintain atomically in native MongoDB and thus should be avoided.
* Related records that are pulled in will be of type `model.Document` specific to that model. Meaning they will have all virtuals and methods attached. In our blogPost example, the pulled in author will be a functioning `authorModel.Document`.
* You can specify hooks at query time which will cascade down into relationships. Using our blog example, when querying the blog, you may want specific hooks to run on authors, you can specify these at query time.
* To populate related data, there are two methods. You can specify the hooks and the required fields, or you can simply reference the field name in the `fields` option.

Example:

To provide an example we'll do a basic blog setup. Lets imagine we have blogPosts, blogAuthors, blogTags, and a images model.

In this example, blogPosts have a single blogAuthor, multiple blogTags, and multiple images. BlogAuthors have a single image. With that spec in mind, lets model it out.

```js
// the models for this relationship
var postModel = new mongolayer.Model({
	collection : "posts",
	fields : [
		{ name : "title", validation : { type : "string" } },
		{ name : "description", validation : { type : "string" } }
	],
	relationships : [
		{ name : "author", type : "single", modelName : "authors", required : true },
		{ name : "tags", type : "multiple", modelName : "tags" },
		{ name : "images", type : "multiple", modelName : "images" }
	]
});

var authorModel = new mongolayer.Model({
	collection : "authors",
	fields : [
		{ name : "name", validation : { type : "string" } }
	],
	relationships : [
		{ name : "image", type : "single", modelName : "images" }
	]
});

var tagModel = new mongolayer.Model({
	collection : "tags",
	fields : [
		{ name : "title", validation : { type : "string" } }
	]
});

var imageModel = new mongolayer.Model({
	collection : "images",
	fields : [
		{ name : "title", validation : { type : "string" } },
		{ name : "src", validation : { type : "string" } },
		{ name : "created", validation : { type : "date" }, default : function() { return new Date() } }
	]
});
```

## Setting Data

For the author, because the name of the relationships is "author" and it's type is "single" the key to set it's value is "author_id". That field expects a `mongolayer.ObjectId`.

For the tags, because the name of the relationship is "tags" and it's type is "multiple" the key to set it's value is "tags_ids". That field expects an array of `mongolayer.ObjectId`. Internally in MongoDB it is stored an array as well, so you can use all manner of array operators when modifying, filtering, or querying the value.

```js
postModel.insert({
	title : "foo",
	description : "bar",
	author_id : myAuthor_id,
	tags : [tag1_id, tag2_id]
}, function(err, doc) {
	// data inserted
});
```

## Populating Relationships

Each declared relationship creates an `afterFind` hook and a virtual of the same name. Either can be used to populate that data. These hooks and virtuals can be nested down into inner relationships as well.

When querying a model you can also pass hooks to execute on related models as well. This is the technique you would use to pull in nested relationships.

In our example, if I pass the hook 'afterFind_author' it will fill in the authors and if I pass in 'author.afterFind_image' it will run the 'afterFind_image' hook on the model which manages the 'author' key.

The merged in data will be accessed at the key for the relationship 'name'. So because I named my author relationship 'author', then I will access the author at 'author'. If I need to get/set it's id, I can use 'doc.author_id'.

### Using virtuals to fold in relationships

The best practice with most queries is to specify only the fields you want. If you specify a field which is a relationship, it will automatically merge that field in.

It is highly recommended to utilize `castDocs : false` at the same time to reduce the clutter of the return and ensure optimal performance.

#### Example

- By specifying the 'author' key, it tells mongolayer to fold in the related data. Under the hood mongolayer utilizes requiredFields and requiredHooks to add author_id to our fields and append the hook 'afterFind_author'. Using the virtual for this behavior simplifies the developer use-case, and obfuscates that complexity.

```js
postModel.find({}, { fields : { title : 1, description : 1, author : 1 } }, function(err, docs) {
	// returned docs will have the structure
	{
		title : "x",
		description : "y",
		author_id : id,
		author : {
			name : "foo",
			image_id : id
		}
	}
});
```

- If you want to pull in the authors image, you can do that as well. As with MongoDB native behavior, by specifying a descendent key on a nested key, you will now only returned the queried keys. This means the query below will no longer return "author.name", because "author.image" was specified in the query, thus making the author find() no longer a SELECT \*. This the query below is no different than `{ title : 1, description : 1, "author.image" : 1 }`
```js
postModel.find({}, { fields : { title : 1, description : 1, author : 1, "author.image" : 1 } }, function(err, docs) {
	// returned docs will have the structure
	{
		_id : id,
		title : "x",
		description : "y",
		author_id : authorId, // added by the virtual system
		author : {
			_id : authorId
			image_id : imageId, // added by the virtual system
			image : {
				_id : imageId,
				title : "title",
				src : "http://www.foo.com/something.jpg"
			}
		}
	}
});
```

```js
// In order to speed things up and reduce the clutter of the return, you can specify castDocs : false in your options
postModel.find({}, { fields : { title : 1, description : 1, "author.image" : 1 }, castDocs : false }, function(err, docs) {
	// returned docs will have the structure
	{
		title : "x",
		description : "y",
		author : {
			image : {
				_id : imageId,
				title : "title",
				src : "http://www.foo.com/something.jpg"
			}
		}
	}
});

// When querying relationships, you can specify fields for inclusion or exclusion as if you were querying that model directly. As with normal mongo syntax, you cannot mix inclusion and exclusion. (except for the _id case).
postModel.find({}, { fields : { title : 1, "author.image.src" : 1 } }, function(err, docs) {
	// returned docs will have the structure
	{
		title : "x",
		author : {
			image : {
				src : "x"
			}
		}
	}
	
	// if there is no image on the author, or no src on the image the author key will be undefined
	{
		title : "x"
	}
});
```

### Using hooks to fold in all data

In cases where you want to pull all fields, then you will need to specify the hooks to signal mongolayer which relationships to populate.

```js
// query blog posts and fold in authors and their images, tags not folded in
postModel.find({}, { hooks : ["afterFind_author", "author.afterFind_image"] }, function(err, docs) {
	if (err) { return cb(err); }
	
	// docs returned will have authors populated and author images populated
	// docs[0].author instanceof mongolayer.Document
	// docs[0].author_id instanceof mongolayer.ObjectId
	// docs[0].author.image instanceof mongolayer.Document
	// docs[0].author.image_id instanceof mongolayer.ObjectId
	
	cb(null);
});
```

```js
// query blog posts and fold in everything
postModel.find({}, { hooks : ["afterFind_author", "author.afterFind_image", "afterFind_tags", "afterFind_images"] }, function(err, docs) {
	if (err) { return cb(err); }
	
	cb(null);
});
```

As you can read in the hook documentation you can specify defaultHooks at the model level this way if no hooks are specified it will run a default set of hooks.

```js
// If we declared our postModel with afterFind defaultHooks it will automatically fold in all related records on a `find({})` unless we were to pass hooks at runtime.
var postModel = new mongolayer.Model({
	collection : "posts",
	fields : [
		{ name : "title", validation : { type : "string" } },
		{ name : "description", validation : { type : "string" } }
	],
	relationships : [
		{ name : "author", type : "single", modelName : "authors", required : true },
		{ name : "tags", type : "multiple", modelName : "tags" },
		{ name : "images", type : "multiple", modelName : "images" }
	],
	defaultHooks : {
		find : ["afterFind_author", "author.afterFind_image", "afterFind_tags", "afterFind_images"]
	}
});

// this will still fold in author, author images, tags and images
postModel.find({}, function(err, docs) {

});

// this will fold fold in nothing because we are passing a value for hooks, causing the defaultHooks to not execute
postModel.find({}, { hooks : [] }, function(err, docs) {

});
```

Lastly you could use `hookRequired : true` when specifying the relationship to make sure it is always ran regardless of what hooks are specified at run time.

**Note:** Be careful when doing this due to performance implications. Nearly always, somewhere down the line you will want to query without pulling in the related records. Be certain you really want this hook to run **always** and not just **most of the time**.

```js
// This module will fold in authors always, regardless of what hooks are passed at runtime
var postModel = new mongolayer.Model({
	collection : "posts",
	fields : [
		{ name : "title", validation : { type : "string" } },
		{ name : "description", validation : { type : "string" } }
	],
	relationships : [
		{ name : "author", type : "single", modelName : "authors", required : true, hookRequired : true },
		{ name : "tags", type : "multiple", modelName : "tags" },
		{ name : "images", type : "multiple", modelName : "images" }
	]
});
```

# API Documentation

## mongolayer

### mongolayer.connectCached(options, cb)

Connect to a mongolayer database. If a call to `mongolayer.connectCached` is made with the same arguments as a previous call, it will re-use the underlying `node-mongodb-native` connection but still give you a new `Connection` instance with no attached models.

**This is the recommended method for connecting through `mongolayer` especially if you connect in unit tests.**

* `options`
	* `connectionString` - `string`- `required` - Official `mongodb` [connection string](https://docs.mongodb.com/manual/reference/connection-string/). You must specify a database name in your connectionString. Example: `mongodb://127.0.0.1/mongolayer"`.
	* `options` - `object` - `optional` - Connection options used by `node-mongodb-native`. Example: `{ poolSize : 10 } }`
* `callback`
	* `Error` or null
	* `mongolayer.Connection`

Example:

```js
mongolayer.connectCached({ connectionString : "mongodb://127.0.0.1/mongolayer" }, function(err, conn) {
	
});

// connect with auth
mongolayer.connectCached({
	connectionString : "mongodb://127.0.0.1/mongolayer",
	options : {
		auth : {
			user : "username",
			password : "password"
		}
	}
}, cb);

// connect to a replSet
mongolayer.connectCached({
	connectionString : "mongodb://repl1:27017,repl2:27017,repl3:27017/dbName",
}, cb);
```

### mongolayer.connect(options, callback)

Connect to a mongolayer database, returns Error and an instance of `mongolayer.Connection`.

This method takes the same arguments as `mongolayer.connectCached`.

Example:

```js
mongolayer.connect({ connectionString : "mongodb://127.0.0.1/mongolayer" }, function(err, conn) {
	
});
```

### mongolayer.toPlain(data)

Converts an instance of a `Document` into a simple JS object without virtuals or methods.

* `data` - `mongolayer.Document` - `required` - Can be a single `Document` or an array of `Document`.

Example:

```js
model.find({}, function(err, docs) {
	var simple = mongolayer.toPlain(docs);
});
```

### mongolayer.testId(str)

Creates a ObjectId with a predictable ID specifically for use in unit-tests where you would like predictable IDs. The string will be hex encoded and appended with "0".

* `str` - `string` - `required` - String that you want to use for the mongoId. Must be 12 characters or less in length.

Example:

```js
var id = mongolayer.testId("foo");
// id === "666f6f000000000000000000"
```

## Connection

### constructor

It is **not** recommended you initialize your own `mongolayer.Connection` manually, instead use `mongolayer.connectCached` or `mongolayer.connect`.

### connection.add(args, callback)

Adds a model to a connection. At this moment is also ensures the collection has any declared indexes.

* `args`
	* `model` - `mongolayer.Model` - `required` - A mongolayer Model to add to the connection.
	* `sync` - `boolean` - `optional` - Whether to sync the state of the Model to the database. This triggers the creation of indexes or the underlying view.
* `callback`
	* `Error` or null

Example:

```js
var model = new mongolayer.Model({ collection : "foo" });
conn.add({ model : model }, function(err) {
	
});
```

### connection.remove(args, cb)

Removes a Model from a Connection. This does not remove data or remove the underlying MongoDB table in any fashion.

* `args`
	* `model` - `mongolayer.Model` - `required` - A mongolayer Model to be removed
* `callback`
	* `Error` or null
	
### connection.removeAll(cb)

Removes all **Models** from a **Connection**. This does not remove data or remove the underlying MongoDB table in any fashion. Sometimes used in unit testing if you want to wipe a `mongolayer.Connection` between each test iteration. Can also use `mongolayer.connectCached` to accomplish the same task.

* `callback`
	* `Error` or null
	
### connection.dropCollection(args, cb)

* `args`
	* `name` - `string` - `required` - The name of the collection to remove
* `callback`
	* `Error` or null

### connection.close(cb)

Closes the underlying `node-mongodb-native` connection.

* `callback`
	* `Error` or null

## Model

### constructor - new mongolayer.Model(args);

Creates an instance of a `mongolayer.Model`.

* `args`
	* `collection` - `string` - `required` - The name of the collection
	* `allowExtraKeys` - `boolean` - `optional` - `false` - Whether the model allows fields which aren't declared to be saved to the DB.
	* `deleteExtraKeys` - `boolean` - `optional` - `false` - Whether the model will delete extra keys that are attempted to be saved to the DB.
	* `fields` - `array` - `optional` - Array of fields to add to the Model. See model.addField for syntax.
	* `virtuals` - `array` - `optional` - Array of virtuals to be added to Documents returned from queries. See model.addVirtual for syntax.
	* `relationships` - `array` - `optional` - Array of relationships. See model.addRelationship for syntax.
	* `indexes` - `array` - `optional` - Array of indexes. See model.addIndex for syntax.
	* `name` - `string` - `optional` - The name of the model. If not passed it will use the name of the collection. This option allows you to have two models using the same underlying MongoDB collection.

### model.addField(args)

Adds a field to a model. This is the basic schema that each document in the collection will have.

These can also be specified by passing a `fields` array to a `mongolayer.Model` constructor.

* `name` - `string` - `required` - Name of the field.
* `validation` - `object` - `required` - Validation schema for the key, using [jsvalidator](https://github.com/simpleviewinc/jsvalidator) syntax.
* `default` - `any` - `optional` - Default value for the field. Can be a function who's return will be the value.
* `required` - `boolean` - `optional` - Whether the field is required before putting into the database.
* `persist` - `boolean` - `optional` - `default true`. If false, then the value of the field is not persisted into the database.
* `toJSON` - `boolean` - `optional` - `default true`. If false, then the value will not serialize to JSON when JSON.stringify() is called on it.

Example:

```js
// add simple string field
model.addField({ name : "foo", validation : { type : "string" } });

// add date field with default filled at runtime
model.addField({ name : "created", validation : { type : "date" }, default : function() { return new Date() } });

// add non-persistent field not-saved to the database but sometimes used to store data during runtime.
model.addField({ name : "_cached", persist : false });
```

### model.addVirtual(args)

Adds a virtual to a model. These are attached with `Object.defineProperty` to each Document that is returned by queries. You can use them for getters, and/or setters.

These can also be specified by passing a `virtuals` array to a `mongolayer.Model` constructor.

* `name` - `string` - `required` - Name of the key to access the virtual
* `get` - `function` - `optional` - Function executed when the key is accessed.
* `set` - `function` - `optional` - Function executed when the key is set.
* `enumerable` - `boolean` - `optional` - `default true` - Whether the key is exposed as enumerable with code such as `for in` loops.
* `cache` - `boolean` - `optional` - `default false` - If true, the virtual will only be evaluate once, subsequent calls will return the first returned value.
* `writable` - `boolean` - `optional` - `default false` - If true, the virtuals value can be set directly, without a setter. Cannot be used with a getter.
* `requiredFields` - `array of strings` - `optional` - An array of requiredFields this virtual depends on. In find() fields, if the virtual is specified for inclusion,
it will automatically ensure that all requiredFields are part of the fields doc, simplifying downstream developer workflows. requiredFields can reference other virtual fields,
allowing developers to chain multiple virtuals together.
* `requiredHooks` - `array of strings` - `optional` - An array of hooks that this virtual depends on. In find() fields, if the virtual is specified for inclusion
it will automatically add these hooks to run.

Virtuals can be executed in `castDocs === false` if they are specified in the `fields` find() option.

Example:

```js
// add a getter to convert a mongolayer ObjectId to a simple string and a setter to convert a string to a mongolayer.ObjectId
// this is used so that in MongoDB you are storing the actual ObjectId, but in your code you can pass strings (which may make things easier)
// this assumes the model has a field called 'user_id' which holds a `mongolayer.ObjectId`
model.addVirtual({
	name : "user_id_string",
	get : function() {
		return this.user_id.toString()
	},
	set : function(val) {
		this.user_id = new mongolayer.ObjectId(val);
	}
});

// add a virtual to convert \r\n in strings into <br/> tags
// this assumes the Model has a field called 'description' which holds a `string`
model.addVirtual({
	name : "description_formatted",
	get : function() {
		return this.description.replace(/(?:\r\n|\r|\n)/g, "<br/>");
	},
	enumerable : false
});

var doc = new mongolayer.Document({ description : "foo\r\nbar" });
console.log(doc.description_formatted);
// "foo<br/>bar"
```

Working with requiredFields

```js
model.addVirtual({
	name : "url",
	get : function() { return "http://www.mydomain/post/" + this.slug + "/"; },
	requiredFields : ["slug"]
});

model.addVirtual({
	name : "slug",
	get : function() { return encodeURI(this.title.toLowerCase().replace(/[^\w ]/g, "").replace(/\s/g, "-")); },
	requiredFields : ["title"]
});

var data = {
	title : "This is a test!",
	description : "My description text"
}

// query and ask for only the url, since the url depends on title and slug both will come back
model.find({}, { fields : { url : 1 } }, function(err, docs) {
	docs[0] === { _id : objectId, title : "This is a test", slug : "this-is-a-test", url : "http://www.mydomain/post/this-is-a-test/" }
});

// query with castDocs and only the specified fields come back, even though our virtual (under the hood) needed some additional fields to operate
model.find({}, { fields : { url : 1 }, castDocs : false }, function(err, docs) {
	docs[0] === { url : "http://www.mydomain/post/this-is-a-test/" }
});
```

**Note:** you cannot query against fields declared as virtuals, you can only query against fields actually stored in the database.

### model.addRelationship(args)

Adds a relationship to a model. This automatically creates an afterFind hook for you can specify to load related records.

This documents the addRelationship call, for specific use cases and examples please see the relationship section of the documentation.

These can also be specified by passing a `relationships` array to a `mongolayer.Model` constructor.

* `args`
	* `name` - `string` - `required` - The name of key where the related record will be populated and the name given to the hook created to populate the records. If type is 'single', then the id for the record is stored at `[name]_id`. If the type is 'multipled', then an array of ids is stored at `[name]_ids`.
	* `type` - `string` - `required` - Possible values are 'single' and 'multiple'. If `single` then each row can only have a single related record. If `multiple` then the related records will be an array.
	* `modelName` - `string` - `required` - The name of the model that this relates to. If no name is passed when initializing the `mongolayer.Model` then modelName will be the name of the collection.
	* `required` - `boolean` - `optional` - If required then records cannot be saved unless they have an associated record(s).

Example:

```js
// adds a required single relationship to a model
model.addRelationship({
	name : "author",
	type : "single",
	modelName : "authors",
	required : true
});

// adds a optional multiple relationship to a model
model.addRelationship({
	name : "tags",
	type : "multiple",
	modelName : "tags"
});
```

### model.addHook(args)

Registers a hook which can be specified at query-time. Hooks provide a powerful mechanism for wrapping all queries in and out of MongoDB.

**Note**: All hook handlers should cb(null, args) or cb(err) (in the event of an error which you want to halt the operation).

These can also be specified by passing a `hooks` array to a `mongolayer.Model` constructor.

* `args`
	* `name` - `string` - `required` - The name of the hook
	* `type` - `string` - `required` - The type of hook that you are creating. Possible options are beforeFind, afterFind, beforeInsert, afterInsert, beforeCount, afterCount, beforeSave, afterSave, beforeUpdate, afterUpdate, beforeRemove, afterRemove.
	* `handler` - `function(args, cb)` - `required` - The handler function which will be executed when the hook is called. The content of `args` depends on the specific hook. See the hook documentation for more information.
	
Example:

```js
// adds a afterFind hook to a model to load in some facebook posts after query
var facebookLibrary = require("someFancyFacebookLibrary");
var async = require("async");

model.addHook({
	name : "facebookPosts",
	type : "afterFind",
	handler : function(args, cb) {
		// check to make sure we we have docs to work with
		if (args.docs.length === 0) {
			return cb(null, args);
		}
		
		var calls = [];
		
		// foreach doc imagine we are loading some data from another source, in this case facebook
		args.docs.forEach(function(val, i) {
			calls.push(function(cb) {
				facebookLibrary.getPosts(val.facebookId, function(err, temp) {
					if (err) { return cb(err); }
					
					// update the doc with the data from our async data source, in this case facebook
					val.facebookPosts = temp;
					
					cb(null);
				});
			});
		});
		
		async.parallel(calls, function(err) {
			if (err) { return cb(err, args); }
			
			cb(null, args);
		});
	}
});
```

### model.addDocumentMethod(args)

Adds a method to be attached to each `mongolayer.Document` retrieved from MongoDB. Methods added to documents are executed by calling `doc.methodName(myArgs)`.

This function basically takes a handler function and attaches it to the `mongolayer.Document` prototype specific to your Model.

These can also be specified by passing a `documentMethods` array to a `mongolayer.Model` constructor.

* `args` - `object` - `required`
	* `name` - `string` - `required` - The name of the method. 
	* `handler` - `function` - `required` - The function which will be executed when the method is called. The `this` scope will be the specific document. The handler function can take any configuration of arguments.

Example:

```js
var model = new mongolayer.Model({
	collection : "users",
	fields : [
		{ name : "name", validation : { type : "string" }, required : true },
		{ name : "permissions", validation : { type : "array", schema : { type : "string" } }, required : true }
	]
});

// add a method to a document that takes two arguments
model.addDocumentMethod({
	name : "hasPermission",
	handler : function(permName) {
		return this.permissions.indexOf(permName) > -1;
	}
});

var doc = new model.Document({
	name : "New Guy",
	permissions : ["canPost", "canEdit"]
});

console.log(doc.hasPermission("canPost"))
// true
console.log(doc.hasPermission("canEdit"))
// true
console.log(doc.hasPermission("canRemove"))
// false
```

### model.addModelMethod(args)

Adds a method to a model. Model methods are executed by calling `model.methods.methodName(myArgs)`.

These can also be specified by passing a `modelMethods` array to a `mongolayer.Model` constructor.

* `args`
	* `name` - `string` - `required` - The name of the method.
	* `handler` - `function` - `required` - The function which will be executed when the method is called. The `this` scope will refer to the model. The handler function can take any configuration of arguments.

Example:

```js
var model = new mongolayer.Model({
	collection : "posts",
	fields : [
		{ name : "title", validation : { type : "string" }, required : true },
		{ name : "description", validation : { type : "string" }, required : true },
		{ name : "active", validation : { type : "boolean" }, required : true },
		{ name : "publish_start", validation : { type : "date" }, default : function() { return new Date() } },
		{ name : "publish_end", validation : { type : "date" } } // optional publish end date
	]
});

// Adds model method to get all posts which are active, and who's publish_start is in the past and, if it has a publish_end, a publish_end in the future
// This way we don't have to replicate the rather complicated filter each time we want to run this query
model.addModelMethod({
	name : "getActivePosts",
	handler : function(cb) {
		this.model.find({
			active : true,
			publish_start : { $lte : new Date() },
			$or : [
				{ publish_end : { $gt : new Date() },
				{ publish_end : { $exists : false } }
			]
		}, cb);
	}
});

// assumes the model has been added to a `mongolayer.Connection`
model.methods.getActivePosts(function(err, docs) {
	// do stuff with active docs
});
```

### model.addIndex(args)

Adds an index to a collection. Indexes are created using `collection.ensureIndex(keys, options)`. Please reference the [official MongoDB ensureIndex docs](http://docs.mongodb.org/manual/reference/method/db.collection.ensureIndex/) for complete documentation on creating and using indexes.

**Note**: MongoDB natively creates an index on `_id`. So there is no need to `addIndex()` for that index.

* `args` - `object` - `required`
	* `keys` - `object` - `required` - The keys object which specifies which keys are part of the index.
	* `options` - `object` - `required` - The options object which specifies the index settings.

Example:

```js
// creates a unique index on the slug key
model.addIndex({
	keys : { slug : 1 },
	options : { unique : true }
});
```

## Querying

### model.aggregate(pipeline, options, cb)

Runs a aggregation query on a mongoDB collection and returns an array of objects.

Hooks: `beforeAggregation` -> `afterAggregation`

Arguments

* `pipeline` - `array` - `required` - MongoDB aggregation pipeline. See official docs
* `options` - `object` - `optional`
	* `maxSize` - `number` - `optional` - Enforce a maxSize at query time to prevent large data sets from being inadvertently returned, returns an Error if violated.
	* `castDocs` - `boolean` - `default false` - *RECOMMENDED false*. If true it will convert the returned docs into instanceof model.Document, allowing access to virtuals. If false, you can utilize `options.virtuals` to execute specific virtuals, which is preferred versus castDocs.
	* `hooks` - `array` - `optional` - Array of hooks to run. See [hooks documentation](#runtime_hooks) for syntax.
	* `virtuals` - `array of strings` - `optional` - An array of virtuals to attach to the returned documents. If used it is assumed that the aggregation will return any dependent data needed to fulfill the virtual.
	
```js
// simple aggregate
model.aggregate([
	{ $match : { foo : "fooValue" } }
], function(err, docs) {
	
});

// with virtuals and hooks
model.aggregate([
	{ $match : { foo : "fooValue" } }
], { virtuals : ["fooVirtual"], hooks : ["beforeAggregate_test", "afterAggregate_test2"] }, function(err, docs) {
	
});
```

### model.promises.aggregate(filter, options)

Returns a promise. Same arguments as `model.aggregate`.

### model.find(filter, options, cb)

Runs a find query on a mongoDB collection and returns an array of `mongolayer.Document`.

Usage of `castDocs : false` and passing `fields` is recommended for performance. When done so it will only return the specified fields, and will pull down less data from MongoDB.

Hooks: `beforeFind` -> `beforeFilter` -> `afterFind`

Arguments

* `filter` - `object` - `required` - Standard mongoDB filter syntax.
* `options` - `object` - `optional`
	* `fields` - `object` - `optional` - Which fields to include in the query. Uses [MongoDB native syntax](http://docs.mongodb.org/manual/tutorial/project-fields-from-query-results/).
	* `options` - `object` - `optional` - An options object which is passed on to `node-mongodb-native` which performs the query. If you need to pass options at that level, pass them here.
	* `sort` - `object` - `optional` - Sort criteria. Uses [MongoDB native syntax](http://docs.mongodb.org/manual/reference/method/cursor.sort/)
	* `limit` - `number` - `optional` - Number of records to retrieve.
	* `skip` - `number` - `optional` - Number of records to skip before retrieving records.
	* `maxSize` - `number` - `optional` - Enforce a maxSize at query time to prevent large data sets from being inadvertently returned, returns an Error if violated.
	* `castDocs` - `boolean` - `default true` - *RECOMMENDED false*. If true it will convert the returned docs into instanceof model.Document, allowing access to virtuals. If false, only virtuals mentioned in the fields object are accessible, which is the recommendataion! castDocs is also recursive, so all relationships will be pulled with castDocs === false as well. If you require virtuals on them, specify it in your fields object.
	* `hooks` - `array` - `optional` - Array of hooks to run. See [hooks documentation](#runtime_hooks) for syntax.
	* `count` - `boolean` - `default false` - If true it will return an object with `{ count : count, docs : docs }` including the full count that matches the query (not just count of returned docs).
	* `context` - `object` - `optional` - If passed, it will be available to all hooks in the descendent query. So this object can be accessed in the hooks and resolvers of relationships.
* `cb` - `function` - `required`
	* `Error` or null
	* `array` of `model.Document`.

Example:

```js
// simple find
model.find({}, function(err, docs) {
	
});

// find which sorts by created, returns 10 posts, and skips the first 10 posts
model.find({}, { sort : { created : 1 }, limit : 10, skip : 10 }, function(err, docs) {
	
});

// castDocs === false
model.find({}, { castDocs : false, fields : { _id : 1, title : 1, description : 1 } }, function(err, docs) {
	// returned data will only contain _id, title, description
});
```

### model.promises.find(filter, options)

Returns a promise. Same arguments as `model.find`.

### model.findById(id, options, cb)

A shortcut for pulling down a specific document from the database.

Hooks: `beforeFind` -> `beforeFilter` -> `afterFind`

Arguments

* `id` - `string` or `mongolayer.ObjectId` - `required` - The _id for a record in string or `mongolayer.ObjectId` form.
* `options` - The same options available to `model.find` please see the docs there.
* `cb` - `function` - `required`
	* `Error` or null
	* `model.Document`

Example:

```js
var doc = new model.Document();

// using string syntax
model.findById(doc.id, function(err, doc) {

});

// using mongolayer.ObjectId syntax
model.findByid(doc._id, function(err, doc) {
	
});
```

### model.promises.findById(id, options)

Returns a promise. Same arguments as `model.findById`.

### model.insert(docs, options, cb)

Runs an insert query on a mongoDB collection and returns an array of `mongolayer.Document`.

Hooks: `beforeInsert` -> `beforePut` (for each doc) -> `afterPut` (for each doc) -> `afterInsert`

**Note**: When running bulk inserts, in the event a `WriteError` occurs in the middle, such as on a key conflict, the records up to that point will still be inserted. In this state, your `afterPut` and `afterInsert` hooks will not run.

Arguments

* `docs` - `object` or `array` - `required` - Can be a single plain javascript object or array of plain javascript objects, or a single `model.Document` or an array of `model.Document`.
* `options` - `object` - `optional`
	* `options` - `object` - `optional` - An options object which is passed on to `node-mongodb-native` which performs the query. If you need to pass options at that level, pass them here.
	* `hooks` - `array` - `optional` - Array of hooks to run. See [hooks documentation](#runtime_hooks) for syntax.
	* `stripEmpty` - `boolean` - `optional` - defaults to true. Removes empty strings, objects, arrays, and undefined values inside of your document.
* `cb` - `function` - `required`
	* `Error` or null
	* If a single document is inserted, then it will return a single `model.Document`, if an array of documents was inserted it will return an array of `model.Document`.
	* `result` writeResult

Example:

```js
// insert plain document
model.insert({ foo : "bar" }, function(err, doc) {
	console.log(doc instanceof model.Document);
	// true
});

// create document first, then insert into DB
var doc = new model.Document({ foo : "bar" });
doc.doSomethingElse();
model.insert(doc, function(err, doc) {
	console.log(doc instanceof model.Document);
	// true
});

// insert array of documents
model.insert([{ foo : "bar" }, { foo : "baz" }], function(err, docs) {
	console.log(docs instanceof Array);
	// true
	console.log(docs[0] instanceof model.Document);
	// true
	console.log(docs[0].foo)
	// "bar"
});
```

### model.save(doc, options, cb)

Runs an save query which inserts a new object if the doc doesn't contain an `_id`. It it does it will overwrite that document if it exists, or upsert it if it doesn't.

`save` is a great general purpose tool for inserting, upserting and replacing records.

**Note**: `save` cannot be used for bulk operations. `save` in mongoDb shell does allow bulk operations, but that is a bug.

Hooks: `beforeSave` -> `beforePut` -> `afterPut` -> `afterSave`

Arguments

* `doc` - `object` or `model.Document` - `required` - Can be a single plain javascript object or a single `model.Document`.
* `options` - `object` - `optional`
	* `options` - `object` - `optional` - An options object which is passed on to `node-mongodb-native` which performs the query. If you need to pass options at that level, pass them here.
	* `hooks` - `array` - `optional` - Array of hooks to run. See [hooks documentation](#runtime_hooks) for syntax.
	* `stripEmpty` - `boolean` - `optional` - defaults to true. Removes empty strings, objects, arrays, and undefined values inside of your document.
* `cb` - `function` - `required`
	* `Error` or null
	* `model.Document`
	* `result` writeResult

### model.remove(filter, options, cb)

Removes records from a collection.

Hooks: `beforeRemove` -> `beforeFilter` -> `afterRemove`

Arguments

* `filter` - `object` - `required` - Standard mongoDB filter syntax.
* `options` - `object` - `optional`
	* `options` - `object` - `optional` - An options object which is passed on to `node-mongodb-native` which performs the query. If you need to pass options at that level, pass them here.
	* `hooks` - `array` - `optional` - Array of hooks to run. See [hooks documentation](#runtime_hooks) for syntax.
* `cb` - `function` - `required`
	* `Error` or null
	* `result` writeResult
	
### model.removeAll(cb)

Removes all records from a collection. This is much faster method of doing `model.remove({}, cb)`.

### model.update(filter, delta, options, cb)

Updates documents in the database. This function works similarly to the native MongoDB update command. For advanced documentation on operators and options please see [the official docs](http://docs.mongodb.org/manual/reference/method/db.collection.update/).

Hooks: `beforeUpdate` -> `beforeFilter` -> `afterUpdate`

Key Points about using `update`

* Mongoose wraps all update options in $set. **Mongolayer does not**, as this is not the behavior mongoDB works natively.
* Mongolayer cannot handle field default values and enforcing required fields when using **any** update operators such as $set or $setOnInsert.
* When using update operators `$set` and `$setOnInsert` are still validated.
* Mongolayer will handle default values, required fields, and validation when doing whole document update syntax `model.update(filter, { foo : "bar" }, cb)`
* Do not use `update` with `upsert` semantics if you want to leverage the `beforePut` and `afterPut` hooks. Instead use `save` it provides the same functionality. This is due to eccentricities of the MongoDB atomic model.

Arguments

* `filter` - `object` - `required` - Standard mongoDB filter syntax.
* `delta` - `object` - `required` - Standard mongoDB change object containing either whole document syntax of update operators such as `$set`.
* `options` - `object` - `optional`
	* `options` - `object` - `optional` - An options object which is passed on to `node-mongodb-native` which performs the query. If you need to pass options at that level, pass them here.
	* `hooks` - `array` - `optional` - Array of hooks to run. See [hooks documentation](#runtime_hooks) for syntax.
	* `stripEmpty` - `boolean` - `optional` - defaults to true. Removes empty strings, objects, arrays, and undefined values inside of your document.
* `cb` - `function` - `required`
	* `Error` or null
	* `result` writeResult
	
### model.count(filter, options, cb)

Returns the count of documents that match a filter.

Hooks: `beforeCount` -> `beforeFilter` -> `afterCount`

Arguments

* `filter` - `object` - `required` - Standard mongoDB filter syntax.
* `options` - `object` - `optional`
	* `options` - `object` - `optional` - An options object which is passed on to `node-mongodb-native` which performs the query. If you need to pass options at that level, pass them here.
	* `hooks` - `array` - `optional` - Array of hooks to run. See [hooks documentation](#runtime_hooks) for syntax.
* `cb` - `function` - `required`
	* `Error` or null
	* `number` of documents

## model properties

A list of public properties which you can access to introspect various functionality of your models.

Do not alter any of the following properties at runtime, but you can safely read their values.

* `model.name` - `string` - Name of the model. Do not alter at run-time.
* `model.connected` - `boolean` - Whether the model is currently attached to a `mongolayer.Connection`.
* `model.collection` - `mongodb.MongoClient.Db.collection` reference. Exposed in case you need functionality not handled by mongolayer.
* `model.Document` - `mongolayer.Document` - The document class specific to this model with virtuals and methods attached to prototype. When running queries each row returns documents of this class.
* `model.methods` - `object` - Object containing methods attached by `model.addModelMethod`. Please do not attach manually.
* `model.ObjectId` - `object` - Shortcut reference to `mongolayer.ObjectId`. Can be used to create or cast ids.
* `model.defaultHooks` - `object` - Object containing arrays for the defaults hooks for each query type

# Development

### Install the repo
* `sudo sv install mongolayer --type=container`

### Run  it locally
* You should be running in the `sv-kubernetes` vagrant environment.
* `cd /sv/containers/dms-core`
* `sudo npm run docker`
	* `yarn test` - Run the tests.