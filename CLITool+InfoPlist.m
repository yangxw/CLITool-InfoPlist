//
//  Copyright (c) 2010 Cédric Luthi
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface NSObject (XcodeInternals)

// PBXBuildContext
- (void) setStringValue:(id)value forDynamicSetting:(id)setting;
- (void) appendStringOrStringListValue:(id)value toDynamicSetting:(id)setting;
- (id) expandedValueForString:(id)string;
- (BOOL) expandedValueIsNonEmptyForString:(id)string;

// PBXTargetBuildContext
- (id) dependencyNodeForName:(id)name createIfNeeded:(BOOL)flag;
- (void) addPath:(id)path toFilePathListWithIdentifier:(id)identifier;

// XCDependencyCommand
- (id) outputNodes;

// XCDependencyNode
- (void) addDependedNode:(id)node;

@end

@interface CLITool_InfoPlist : NSObject
@end

@implementation CLITool_InfoPlist

static IMP IMP_PBXLinkerSpecificationLd_doSpecialDependencySetupForCommand_withInputNodes_inBuildContext_ = NULL;

static id callPBXApplicationProductTypeMethod(id self, SEL selector, id buildContext)
{
	// May filter on [[buildContext target] name] for debugging
	if ([buildContext expandedValueIsNonEmptyForString:@"$(INFOPLIST_FILE)"])
	{
		[buildContext setStringValue:@"_$(PRODUCT_NAME)" forDynamicSetting:@"WRAPPER_NAME"];
		[buildContext setStringValue:@"_$(PRODUCT_NAME)/$(INFOPLIST_FILE)" forDynamicSetting:@"INFOPLIST_PATH"];
	}
	
	Class PBXApplicationProductType = NSClassFromString(@"PBXApplicationProductType");
	
	Method method = class_getInstanceMethod(PBXApplicationProductType, selector);
	IMP implementation = method_getImplementation(method);
	return implementation(self, selector, buildContext);
}

// MARK: PBXToolProductType

+ (id) linkerSpecificationForObjectFilesInTargetBuildContext:(id)buildContext
{
	if ([buildContext expandedValueIsNonEmptyForString:@"$(INFOPLIST_FILE)"])
	{
		NSArray *sectcreate = [NSArray arrayWithObjects:@"-sectcreate", @"__TEXT", @"__info_plist", @"$(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)", nil];
		[buildContext appendStringOrStringListValue:sectcreate toDynamicSetting:@"OTHER_LDFLAGS"];
	}
	
	id result = callPBXApplicationProductTypeMethod(self, _cmd, buildContext);
	// May log [result commandLineForAutogeneratedOptionsInTargetBuildContext:context] for debugging
	return result;
}

+ (void) computeProductDependenciesInTargetBuildContext:(id)buildContext
{
	callPBXApplicationProductTypeMethod(self, _cmd, buildContext);
	id productPath = [buildContext expandedValueForString:@"$(TARGET_BUILD_DIR)/$(FULL_PRODUCT_NAME)"];
	[buildContext addPath:productPath toFilePathListWithIdentifier:@"FilesToClean"];
}

+ (void) defineAuxiliaryFilesInTargetBuildContext:(id)buildContext
{
	callPBXApplicationProductTypeMethod(self, _cmd, buildContext);
}

+ (id) computeProductTouchActionInTargetBuildContext:(id)buildContext
{
	return callPBXApplicationProductTypeMethod(self, _cmd, buildContext);
}

// MARK: PBXLinkerSpecificationLd

+ (id) doSpecialDependencySetupForCommand:(id)command withInputNodes:(id)inputNodes inBuildContext:(id)buildContext
{
	if ([buildContext expandedValueIsNonEmptyForString:@"$(INFOPLIST_FILE)"])
	{
		id productNode = [[command outputNodes] lastObject];
		id infoPlistFile = [buildContext expandedValueForString:@"$(INFOPLIST_FILE)"];
		id infoPlistNode = [buildContext dependencyNodeForName:infoPlistFile createIfNeeded:NO];
		[productNode addDependedNode:infoPlistNode];
	}
	
	return IMP_PBXLinkerSpecificationLd_doSpecialDependencySetupForCommand_withInputNodes_inBuildContext_(self, _cmd, command, inputNodes, buildContext);
}

// MARK: Plugin

+ (void) pluginDidLoad:(NSBundle *)plugin
{
	Class PBXToolProductType = NSClassFromString(@"PBXToolProductType");
	
	SEL linkerSpecificationForObjectFilesInTargetBuildContext_ = @selector(linkerSpecificationForObjectFilesInTargetBuildContext:);
	SEL computeProductDependenciesInTargetBuildContext_ = @selector(computeProductDependenciesInTargetBuildContext:);
	SEL defineAuxiliaryFilesInTargetBuildContext_ = @selector(defineAuxiliaryFilesInTargetBuildContext:);
	SEL computeProductTouchActionInTargetBuildContext_ = @selector(computeProductTouchActionInTargetBuildContext:);
	SEL doSpecialDependencySetupForCommand_withInputNodes_inBuildContext_ = @selector(doSpecialDependencySetupForCommand:withInputNodes:inBuildContext:);
	
	Method my_linkerSpecificationForObjectFilesInTargetBuildContext_ = class_getClassMethod(self, linkerSpecificationForObjectFilesInTargetBuildContext_);
	Method my_computeProductDependenciesInTargetBuildContext_ = class_getClassMethod(self, computeProductDependenciesInTargetBuildContext_);
	Method my_defineAuxiliaryFilesInTargetBuildContext_ = class_getClassMethod(self, defineAuxiliaryFilesInTargetBuildContext_);
	Method my_computeProductTouchActionInTargetBuildContext_ = class_getClassMethod(self, computeProductTouchActionInTargetBuildContext_);
	Method my_doSpecialDependencySetupForCommand_withInputNodes_inBuildContext_ = class_getClassMethod(self, doSpecialDependencySetupForCommand_withInputNodes_inBuildContext_);
	
	Class PBXLinkerSpecificationLd = NSClassFromString(@"PBXLinkerSpecificationLd");
	Method PBXLinkerSpecificationLd_doSpecialDependencySetupForCommand_withInputNodes_inBuildContext_ = class_getInstanceMethod(PBXLinkerSpecificationLd, doSpecialDependencySetupForCommand_withInputNodes_inBuildContext_);
	IMP_PBXLinkerSpecificationLd_doSpecialDependencySetupForCommand_withInputNodes_inBuildContext_ = method_getImplementation(PBXLinkerSpecificationLd_doSpecialDependencySetupForCommand_withInputNodes_inBuildContext_);	
	method_setImplementation(PBXLinkerSpecificationLd_doSpecialDependencySetupForCommand_withInputNodes_inBuildContext_, method_getImplementation(my_doSpecialDependencySetupForCommand_withInputNodes_inBuildContext_));

	BOOL added, success = YES;
	
	added = class_addMethod(PBXToolProductType, linkerSpecificationForObjectFilesInTargetBuildContext_, method_getImplementation(my_linkerSpecificationForObjectFilesInTargetBuildContext_), method_getTypeEncoding(my_defineAuxiliaryFilesInTargetBuildContext_));
	success = success && added;
	added = class_addMethod(PBXToolProductType, computeProductDependenciesInTargetBuildContext_, method_getImplementation(my_computeProductDependenciesInTargetBuildContext_), method_getTypeEncoding(my_computeProductDependenciesInTargetBuildContext_));
	success = success && added;
	added = class_addMethod(PBXToolProductType, defineAuxiliaryFilesInTargetBuildContext_, method_getImplementation(my_defineAuxiliaryFilesInTargetBuildContext_), method_getTypeEncoding(my_defineAuxiliaryFilesInTargetBuildContext_));
	success = success && added;
	added = class_addMethod(PBXToolProductType, computeProductTouchActionInTargetBuildContext_, method_getImplementation(my_computeProductTouchActionInTargetBuildContext_), method_getTypeEncoding(my_computeProductTouchActionInTargetBuildContext_));
	success = success && added;
	
	NSString *pluginName = [[[plugin bundlePath] lastPathComponent] stringByDeletingPathExtension];
	NSString *version = [plugin objectForInfoDictionaryKey:@"CFBundleVersion"];
	if (success)
		NSLog(@"%@ %@ loaded successfully", pluginName, version);
	else
		NSLog(@"%@ %@ failed to load", pluginName, version);
}

@end
