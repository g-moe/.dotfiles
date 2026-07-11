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
	var homePath = asString($.NSHomeDirectory());
	return homePath + "/Library/Application Support/com.apple.sharedfilelist";
}

function favoriteItemsFilePath() {
	var basePath = sharedFileListBasePath();
	var sfl4Path = basePath + "/com.apple.LSSharedFileList.FavoriteItems.sfl4";
	var sfl3Path = basePath + "/com.apple.LSSharedFileList.FavoriteItems.sfl3";
	var fileManager = $.NSFileManager.defaultManager;

	if (fileManager.fileExistsAtPath(sfl4Path)) {
		return sfl4Path;
	}

	if (fileManager.fileExistsAtPath(sfl3Path)) {
		return sfl3Path;
	}

	if (currentMajorVersion() >= 26) {
		return sfl4Path;
	}

	return sfl3Path;
}

function ensureDirectory(path) {
	var fileManager = $.NSFileManager.defaultManager;
	var error = Ref();
	if (
		!fileManager.createDirectoryAtPathWithIntermediateDirectoriesAttributesError(
			path,
			true,
			$(),
			error,
		)
	) {
		var details = error[0]
			? asString(error[0].localizedDescription)
			: "unknown error";
		fail("Unable to create directory: " + path + " (" + details + ")");
	}
}

function bookmarkForPath(path) {
	var url = $.NSURL.fileURLWithPath(path);
	var error = Ref();
	var bookmark =
		url.bookmarkDataWithOptionsIncludingResourceValuesForKeysRelativeToURLError(
			0,
			$(),
			$(),
			error,
		);
	if (isNil(bookmark)) {
		var details = error[0]
			? asString(error[0].localizedDescription)
			: "unknown error";
		fail("Unable to create bookmark for path: " + path + " (" + details + ")");
	}

	return bookmark;
}

function targetItems(targetPaths) {
	var newItems = $.NSMutableArray.array;
	var i;

	for (i = 0; i < targetPaths.length; i += 1) {
		var targetPath = targetPaths[i];
		var targetItem = $.NSMutableDictionary.dictionary;
		targetItem.setObjectForKey(bookmarkForPath(targetPath), "Bookmark");
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

function saveRoot(root, filePath) {
	var encoded = $.NSKeyedArchiver.archivedDataWithRootObject(root);
	if (isNil(encoded)) {
		fail("Unable to archive Finder sidebar data.");
	}

	if (!encoded.writeToFileAtomically(filePath, true)) {
		fail("Unable to write Finder sidebar file: " + filePath);
	}
}

function configureSidebar(rawPaths) {
	if (rawPaths === undefined || rawPaths === null || rawPaths.length === 0) {
		fail(
			"Usage: mac-finder-sidebar.js <absolute-path-1> <absolute-path-2> [...]",
		);
	}

	var normalizedPaths = [];
	var seen = {};
	var i;

	for (i = 0; i < rawPaths.length; i += 1) {
		var normalized = standardizePath(rawPaths[i]);
		if (!seen[normalized]) {
			seen[normalized] = true;
			normalizedPaths.push(normalized);
		}
	}

	var sidebarPath = favoriteItemsFilePath();
	ensureDirectory(sharedFileListBasePath());

	var root = $.NSMutableDictionary.dictionary;
	var properties = $.NSMutableDictionary.dictionary;
	properties.setObjectForKey(
		$.NSNumber.numberWithInt(1),
		"com.apple.LSSharedFileList.ForceTemplateIcons",
	);
	root.setObjectForKey(properties, "properties");
	root.setObjectForKey(targetItems(normalizedPaths), "items");

	saveRoot(root, sidebarPath);
}

// oxlint-disable-next-line no-unused-vars -- JXA calls this entrypoint by name.
function run(argv) {
	configureSidebar(argv);
}
