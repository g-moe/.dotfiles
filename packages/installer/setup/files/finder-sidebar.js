ObjC.import("Foundation");

function fail(message) {
	throw new Error(message);
}

function isNil(value) {
	return value === null || value === undefined;
}

function asString(value) {
	return ObjC.unwrap(value);
}

function standardizePath(path) {
	return asString($(path).stringByStandardizingPath);
}

function currentMajorVersion() {
	return $.NSProcessInfo.processInfo.operatingSystemVersion.majorVersion;
}

function sharedFileListBasePath() {
	return (
		asString($.NSHomeDirectory()) +
		"/Library/Application Support/com.apple.sharedfilelist"
	);
}

function favoriteItemsFilePath() {
	var basePath = sharedFileListBasePath();
	var sfl4Path = basePath + "/com.apple.LSSharedFileList.FavoriteItems.sfl4";
	var sfl3Path = basePath + "/com.apple.LSSharedFileList.FavoriteItems.sfl3";
	var fileManager = $.NSFileManager.defaultManager;

	if (fileManager.fileExistsAtPath(sfl4Path)) return sfl4Path;
	if (fileManager.fileExistsAtPath(sfl3Path)) return sfl3Path;
	return currentMajorVersion() >= 26 ? sfl4Path : sfl3Path;
}

function ensureDirectory(path) {
	var error = Ref();
	if (
		!$.NSFileManager.defaultManager.createDirectoryAtPathWithIntermediateDirectoriesAttributesError(
			path,
			true,
			$(),
			error,
		)
	) {
		fail("Unable to create directory: " + path);
	}
}

function bookmarkForPath(path) {
	var error = Ref();
	var bookmark = $.NSURL.fileURLWithPath(
		path,
	).bookmarkDataWithOptionsIncludingResourceValuesForKeysRelativeToURLError(
		0,
		$(),
		$(),
		error,
	);
	if (isNil(bookmark)) fail("Unable to create bookmark for path: " + path);
	return bookmark;
}

function targetItems(targetPaths) {
	var newItems = $.NSMutableArray.array;
	for (var i = 0; i < targetPaths.length; i += 1) {
		var targetItem = $.NSMutableDictionary.dictionary;
		targetItem.setObjectForKey(bookmarkForPath(targetPaths[i]), "Bookmark");
		targetItem.setObjectForKey(
			$.NSDictionary.dictionary,
			"CustomItemProperties",
		);
		targetItem.setObjectForKey($.NSUUID.UUID.UUIDString, "uuid");
		targetItem.setObjectForKey($.NSNumber.numberWithInt(0), "visibility");
		newItems.addObject(targetItem);
	}
	return newItems;
}

function configureSidebar(rawPaths) {
	if (!rawPaths || rawPaths.length === 0) fail("No sidebar paths were given.");
	var paths = [];
	var seen = {};
	for (var i = 0; i < rawPaths.length; i += 1) {
		var normalized = standardizePath(rawPaths[i]);
		if (!seen[normalized]) {
			seen[normalized] = true;
			paths.push(normalized);
		}
	}

	var filePath = favoriteItemsFilePath();
	ensureDirectory(sharedFileListBasePath());
	var root = $.NSMutableDictionary.dictionary;
	var properties = $.NSMutableDictionary.dictionary;
	properties.setObjectForKey(
		$.NSNumber.numberWithInt(1),
		"com.apple.LSSharedFileList.ForceTemplateIcons",
	);
	root.setObjectForKey(properties, "properties");
	root.setObjectForKey(targetItems(paths), "items");
	var encoded = $.NSKeyedArchiver.archivedDataWithRootObject(root);
	if (isNil(encoded) || !encoded.writeToFileAtomically(filePath, true)) {
		fail("Unable to write Finder sidebar file: " + filePath);
	}
}

// oxlint-disable-next-line no-unused-vars -- osascript calls this entry point.
function run(argv) {
	configureSidebar(argv);
}
