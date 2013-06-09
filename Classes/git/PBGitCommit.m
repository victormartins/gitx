//
//  PBGitCommit.m
//  GitTest
//
//  Created by Pieter de Bie on 13-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitCommit.h"
#import "PBGitSHA.h"
#import "PBGitDefaults.h"

#import <ObjectiveGit/ObjectiveGit.h>

NSString * const kGitXCommitType = @"commit";

@interface PBGitCommit ()

@property (nonatomic, weak) PBGitRepository *repository;
@property (nonatomic, strong) GTCommit *gtCommit;
@property (nonatomic, assign) git_oid oid;
@property (nonatomic, strong) NSArray *parents;

@property (nonatomic, strong) NSString *patch;

@end


@implementation PBGitCommit

- (NSDate *) date
{
	return self.gtCommit.commitDate;
}

- (NSString *) dateString
{
	NSDateFormatter* formatter = [[NSDateFormatter alloc] initWithDateFormat:@"%Y-%m-%d %H:%M:%S" allowNaturalLanguage:NO];
	return [formatter stringFromDate: self.date];
}

- (NSArray*) treeContents
{
	return self.tree.children;
}

/*+ (PBGitCommit *)commitWithRepository:(PBGitRepository*)repo andSha:(PBGitSHA *)newSha
{
	return [[self alloc] initWithRepository:repo andSha:newSha];
}
*/
- (id)initWithRepository:(PBGitRepository *)repo andCommit:(git_oid)oid
{
	self = [super init];
	if (!self) {
		return nil;
	}
	self.repository = repo;
	self.oid = oid;
	
	return self;
}

- (GTCommit *)gtCommit
{
	if (!self->_gtCommit) {
		NSError *error = nil;
		GTObject *object = [self.repository.gtRepo lookupObjectByOid:&self->_oid error:&error];
		if ([object isKindOfClass:[GTCommit class]]) {
			self.gtCommit = (GTCommit *)object;
		}
	}
	assert(self->_gtCommit);
	return self->_gtCommit;
}

- (NSArray *)parents
{
	if (!self->_parents) {
		NSArray *gtParents = self.gtCommit.parents;
		NSMutableArray *parents = [NSMutableArray arrayWithCapacity:gtParents.count];
		for (GTCommit *parent in gtParents) {
			[parents addObject:[PBGitSHA shaWithString:parent.sha]];
		}
		self.parents = parents;
	}
	return self->_parents;
}

- (NSString *)subject
{
	return self.gtCommit.messageSummary;
}

- (NSString *)author
{
	NSString *result = self.gtCommit.author.name;
	return result;
}

- (NSString *)committer
{
	GTSignature *sig = self.gtCommit.committer;
	if (![sig isEqual:self.gtCommit.author]) {
		return sig.name
		;
	}
	return nil;
}

- (NSString *)SVNRevision
{
	NSString *result = nil;
	if ([self.repository hasSVNRemote])
	{
		// get the git-svn-id from the message
		NSArray *matches = nil;
		NSString *string = self.gtCommit.message;
		NSError *error = nil;
		// Regular expression for pulling out the SVN revision from the git log
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^git-svn-id: .*@(\\d+) .*$" options:NSRegularExpressionAnchorsMatchLines error:&error];
		
		if (string) {
			matches = [regex matchesInString:string options:0 range:NSMakeRange(0, [string length])];
			for (NSTextCheckingResult *match in matches)
			{
				NSRange matchRange = [match rangeAtIndex:1];
				NSString *matchString = [string substringWithRange:matchRange];
				result = matchString;
			}
		}
	}
	return result;
}

- (PBGitSHA *)sha
{
	return [PBGitSHA shaWithOID:self.oid];
}

- (NSString *)realSha
{
	return self.gtCommit.sha;
}

- (BOOL) isOnSameBranchAs:(PBGitCommit *)otherCommit
{
	if (!otherCommit)
		return NO;

	if ([self isEqual:otherCommit])
		return YES;

	return [self.repository isOnSameBranch:otherCommit.sha asSHA:self.sha];
}

- (BOOL) isOnHeadBranch
{
	return [self isOnSameBranchAs:[self.repository headCommit]];
}

- (BOOL)isEqual:(id)otherCommit
{
	if (self == otherCommit)
		return YES;

	if (!otherCommit)
		return NO;

	if (![otherCommit isMemberOfClass:[PBGitCommit class]])
		return NO;

	return memcmp(&self->_oid, &((PBGitCommit *)otherCommit)->_oid, sizeof(git_oid)) == 0;
}

- (NSUInteger)hash
{
	return [self.sha hash];
}

// FIXME: Remove this method once it's unused.
- (NSString*) details
{
	return @"";
}

- (NSString *) patch
{
	if (self->_patch != nil)
		return _patch;

	NSString *p = [self.repository outputForArguments:[NSArray arrayWithObjects:@"format-patch",  @"-1", @"--stdout", [self realSha], nil]];
	// Add a GitX identifier to the patch ;)
	self.patch = [[p substringToIndex:[p length] -1] stringByAppendingString:@"+GitX"];
	return self->_patch;
}

- (PBGitTree*) tree
{
	return [PBGitTree rootForCommit: self];
}

- (void)addRef:(PBGitRef *)ref
{
	if (!self.refs)
		self.refs = [NSMutableArray arrayWithObject:ref];
	else
		[self.refs addObject:ref];
}

- (void)removeRef:(id)ref
{
	if (!self.refs)
		return;

	[self.refs removeObject:ref];
}

- (BOOL) hasRef:(PBGitRef *)ref
{
	if (!self.refs)
		return NO;

	for (PBGitRef *existingRef in self.refs)
		if ([existingRef isEqualToRef:ref])
			return YES;

	return NO;
}

- (NSMutableArray *)refs
{
	return [[self.repository refs] objectForKey:self.sha];
}

- (void) setRefs:(NSMutableArray *)refs
{
	[[self.repository refs] setObject:refs forKey:self.sha];
}


+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name {
	return NO;
}


#pragma mark <PBGitRefish>

- (NSString *) refishName
{
	return [self realSha];
}

- (NSString *) shortName
{
	return self.gtCommit.shortSha;
}

- (NSString *) refishType
{
	return kGitXCommitType;
}

@end