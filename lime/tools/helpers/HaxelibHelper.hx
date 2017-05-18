package lime.tools.helpers;


import haxe.Json;
import lime.project.Architecture;
import lime.project.Haxelib;
import lime.project.Platform;
import lime.project.Version;
import sys.io.File;
import sys.FileSystem;


class HaxelibHelper {
	
	
	public static var pathOverrides = new Map<String, String> ();
	
	private static var repositoryPath:String;
	private static var paths = new Map<String, String> ();
	private static var versions = new Map<String, Version> ();
	
	
	public static function findFolderMatch (haxelib:Haxelib, directory:String):Version {
		
		var versions = new Array<Version> ();
		var version:Version;
		
		try {
			
			for (file in FileSystem.readDirectory (directory)) {
				
				try {
					
					version = StringTools.replace (file, ",", ".");
					versions.push (version);
					
				} catch (e:Dynamic) {}
				
			}
			
		} catch (e:Dynamic) {}
		
		return findMatch (haxelib, versions);
		
	}
	
	
	public static function findMatch (haxelib:Haxelib, otherVersions:Array<Version>):Version {
		
		var matches = [];
		
		for (otherVersion in otherVersions) {
			
			if (haxelib.versionMatches (otherVersion)) {
				
				matches.push (otherVersion);
				
			}
			
		}
		
		if (matches.length == 0) return null;
		
		var bestMatch = null;
		
		for (match in matches) {
			
			if (bestMatch == null || match > bestMatch) {
				
				bestMatch = match;
				
			}
			
		}
		
		return bestMatch;
		
	}
	
	
	public static function getRepositoryPath ():String {
		
		if (repositoryPath == null) {
			
			var cache = LogHelper.verbose;
			LogHelper.verbose = false;
			var output = "";
			
			try {
				
				var cacheDryRun = ProcessHelper.dryRun;
				ProcessHelper.dryRun = false;
				
				output = ProcessHelper.runProcess (Sys.getEnv ("HAXEPATH"), "haxelib", [ "config" ], true, true, true);
				if (output == null) output = "";
				
				ProcessHelper.dryRun = cacheDryRun;
				
			} catch (e:Dynamic) { }
			
			LogHelper.verbose = cache;
			
			repositoryPath = StringTools.trim (output);
			
		}
		
		return repositoryPath;
		
	}
	
	
	public static function getPath (haxelib:Haxelib, validate:Bool = false, clearCache:Bool = false):String {
		
		var name = haxelib.name;
		
		if (pathOverrides.exists (name)) {
			
			if (!versions.exists (name)) {
				
				versions.set (name, getPathVersion (pathOverrides.get (name)));
				
			}
			
			return pathOverrides.get (name);
			
		}
		
		if (haxelib.version != null && haxelib.version != "") {
			
			name += ":" + haxelib.version;
			
		}
		
		if (pathOverrides.exists (name)) {
			
			if (!versions.exists (name)) {
				
				var version = getPathVersion (pathOverrides.get (name));
				versions.set (haxelib.name, version);
				versions.set (name, version);
				
			}
			
			return pathOverrides.get (name);
			
		}
		
		if (clearCache) {
			
			paths.remove (name);
			versions.remove (name);
			
		}
		
		if (!paths.exists (name)) {
			
			var libraryPath = PathHelper.combine (getRepositoryPath (), haxelib.name);
			var result = "";
			
			if (FileSystem.exists (libraryPath)) {
				
				var devPath = PathHelper.combine (libraryPath, ".dev");
				var currentPath = PathHelper.combine (libraryPath, ".current");
				var matched = false, version;
				
				if (haxelib.version != "" && haxelib.version != null) {
					
					if (FileSystem.exists (devPath)) {
						
						result = StringTools.trim (File.getContent (devPath));
						
						if (FileSystem.exists (result)) {
							
							version = getPathVersion (result);
							
							if (haxelib.version == "dev" || haxelib.versionMatches (version)) {
								
								matched = true;
								
							}
							
						}
						
					}
					
					if (!matched) {
						
						var match = findFolderMatch (haxelib, libraryPath);
						
						if (match != null) {
							
							result = PathHelper.combine (libraryPath, StringTools.replace (match, ".", ","));
							
						} else {
							
							result = "";
							
						}
						
					}
					
				} else {
					
					if (FileSystem.exists (devPath)) {
						
						result = StringTools.trim (File.getContent (devPath));
						
					} else {
						
						result = StringTools.trim (File.getContent (currentPath));
						result = PathHelper.combine (libraryPath, StringTools.replace (result, ".", ","));
						
					}
					
				}
				
				if (result == null) result == "";
				if (result != "" && !FileSystem.exists (result)) result = "";
				
			}
			
			if (validate && result == "") {
				
				if (haxelib.version != "") {
					
					LogHelper.error ("Could not find haxelib \"" + haxelib.name + "\" version \"" + haxelib.version + "\", does it need to be installed?");
					
				} else {
					
					LogHelper.error ("Could not find haxelib \"" + haxelib.name + "\", does it need to be installed?");
					
				}
				
			}
			
			// if (validate) {
				
			// 	if (result == "") {
					
			// 		if (output.indexOf ("does not have") > -1) {
						
			// 			var directoryName = "";
						
			// 			if (PlatformHelper.hostPlatform == Platform.WINDOWS) {
							
			// 				directoryName = "Windows";
							
			// 			} else if (PlatformHelper.hostPlatform == Platform.MAC) {
							
			// 				directoryName = PlatformHelper.hostArchitecture == Architecture.X64 ? "Mac64" : "Mac";
							
			// 			} else {
							
			// 				directoryName = PlatformHelper.hostArchitecture == Architecture.X64 ? "Linux64" : "Linux";
							
			// 			}
						
			// 			LogHelper.error ("haxelib \"" + haxelib.name + "\" does not have an \"ndll/" + directoryName + "\" directory");
						
			// 		} else if (output.indexOf ("haxelib install ") > -1 && output.indexOf ("haxelib install " + haxelib.name) == -1) {
						
			// 			var start = output.indexOf ("haxelib install ") + 16;
			// 			var end = output.lastIndexOf ("'");
			// 			var dependencyName = output.substring (start, end);
						
			// 			LogHelper.error ("Could not find haxelib \"" + dependencyName + "\" (dependency of \"" + haxelib.name + "\"), does it need to be installed?");
						
			// 		} else {
						
			// 			if (haxelib.version != "") {
							
			// 				LogHelper.error ("Could not find haxelib \"" + haxelib.name + "\" version \"" + haxelib.version + "\", does it need to be installed?");
							
			// 			} else {
							
			// 				LogHelper.error ("Could not find haxelib \"" + haxelib.name + "\", does it need to be installed?");
							
			// 			}
						
			// 		}
					
			// 	}
				
			// }
			
			paths.set (name, result);
			
			if (haxelib.version != "" && haxelib.version != null) {
				
				paths.set (haxelib.name, result);
				var version = getPathVersion (result);
				
				versions.set (name, version);
				versions.set (haxelib.name, version);
				
			} else {
				
				versions.set (name, getPathVersion (result));
				
			}
			
		}
		
		return paths.get (name);
		
	}
	
	
	public static function getPathVersion (path:String):Version {
		
		path = PathHelper.combine (path, "haxelib.json");
		
		if (FileSystem.exists (path)) {
			
			var json = Json.parse (File.getContent (path));
			
			try {
				
				var versionString:String = json.version;
				var version:Version = versionString;
				return version;
				
			} catch (e:Dynamic) {}
			
		}
		
		return null;
		
	}
	
	
	public static function getVersion (haxelib:Haxelib = null):Version {
		
		var clearCache = false;
		
		if (haxelib == null) {
			
			haxelib = new Haxelib ("lime");
			clearCache = true;
			
		}
		
		getPath (haxelib, true, clearCache);
		
		//if (haxelib.version != "") {
			
			//return haxelib.version;
			
		//}
		
		return versions.get (haxelib.name);
		
	}
	
	
	public static function setOverridePath (haxelib:Haxelib, path:String):Void {
		
		var name = haxelib.name;
		var version = getPathVersion (path);
		
		pathOverrides.set (name, path);
		pathOverrides.set (name + ":" + version, path);
		
		versions.set (name, version);
		versions.set (name + ":" + version, version);
		
	}
	
	
}