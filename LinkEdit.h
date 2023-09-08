/*
 *  LinkEdit.h
 *  MachOView
 *
 *  Created by psaghelyi on 20/07/2010.
 *
 */

#import "MachOLayout.h"
@interface MachOLayout (LinkEdit)

- (MVNode *) createRelocNode:(MVNode *)parent
                     caption:(NSString *)caption
                    location:(uint32_t)location
                      length:(uint32_t)length
                 baseAddress:(uint32_t)baseAddress;

- (MVNode *) createReloc64Node:(MVNode *)parent
                       caption:(NSString *)caption
                      location:(uint32_t)location
                        length:(uint32_t)length
                   baseAddress:(uint64_t)baseAddress;

- (MVNode *) createSymbolsNode:(MVNode *)parent
                       caption:(NSString *)caption
                      location:(uint32_t)location
                        length:(uint32_t)length;

- (MVNode *) createSymbols64Node:(MVNode *)parent
                         caption:(NSString *)caption
                        location:(uint32_t)location
                          length:(uint32_t)length;

- (MVNode *) createReferencesNode:(MVNode *)parent
                          caption:(NSString *)caption
                         location:(uint32_t)location
                           length:(uint32_t)length;

- (MVNode *) createISymbolsNode:(MVNode *)parent
                        caption:(NSString *)caption
                       location:(uint32_t)location
                         length:(uint32_t)length;

- (MVNode *) createISymbols64Node:(MVNode *)parent
                          caption:(NSString *)caption
                         location:(uint32_t)location
                           length:(uint32_t)length;

- (MVNode *) createTOCNode:(MVNode *)parent
                   caption:(NSString *)caption
                  location:(uint32_t)location
                    length:(uint32_t)length;

- (MVNode *) createTOC64Node:(MVNode *)parent
                     caption:(NSString *)caption
                    location:(uint32_t)location
                      length:(uint32_t)length;

- (MVNode *) createModulesNode:(MVNode *)parent
                       caption:(NSString *)caption
                      location:(uint32_t)location
                        length:(uint32_t)length;

- (MVNode *) createModules64Node:(MVNode *)parent
                         caption:(NSString *)caption
                        location:(uint32_t)location
                          length:(uint32_t)length;

- (MVNode *) createTwoLevelHintsNode:(MVNode *)parent
                             caption:(NSString *)caption
                            location:(uint32_t)location
                              length:(uint32_t)length
                               index:(uint32_t)index;

- (MVNode *) createSplitSegmentNode:(MVNode *)parent
                            caption:(NSString *)caption
                           location:(uint32_t)location
                             length:(uint32_t)length
                        baseAddress:(uint64_t)baseAddress;

- (MVNode *) createFunctionStartsNode:(MVNode *)parent
                              caption:(NSString *)caption
                             location:(uint32_t)location
                               length:(uint32_t)length
                          baseAddress:(uint64_t)baseAddress;

- (MVNode *) createDataInCodeEntriesNode:(MVNode *)parent
                                 caption:(NSString *)caption
                                location:(uint32_t)location
                                  length:(uint32_t)length;


- (MVNode *) createChainedFixupsNode:(MVNode *)parent
                             caption:(NSString *)caption
                            location:(uint32_t)location
                              length:(uint32_t)length;

@end

