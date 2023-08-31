/*
 *  ObjC.mm
 *  MachOView
 *
 *  Created by Peter Saghelyi on 17/10/2011.
 *
 */

#import "ObjC.h"
#import "ReadWrite.h"
#import "DataController.h"

/* masks for objc_image_info.flags */
#define OBJC_IMAGE_IS_REPLACEMENT   (1<<0)
#define OBJC_IMAGE_SUPPORTS_GC      (1<<1)
#define OBJC_IMAGE_GC_ONLY          (1<<2)

/* Values for class_ro_t->flags */
#define RO_META                     (1<<0)
#define RO_ROOT                     (1<<1)
#define RO_HAS_CXX_STRUCTORS        (1<<2)
#define RO_HAS_LOAD_METHOD          (1<<3)
#define RO_HIDDEN                   (1<<4)
#define RO_EXCEPTION                (1<<5)
#define RO_HAS_SWIFT_INITIALIZER    (1<<6)
#define RO_IS_ARC                   (1<<7)
#define RO_HAS_CXX_DTOR_ONLY        (1<<8)
#define RO_HAS_WEAK_WITHOUT_ARC     (1<<9)
#define RO_FORBIDS_ASSOCIATED_OBJECTS (1<<10)

using namespace std;

//--------------------- ObjC ----------------------------------------

struct objc_image_info 
{
  uint32_t version;
  uint32_t flags;
};

struct objc_module_t 
{
  uint32_t version;
  uint32_t size;
  uint32_t name;              // char * (32-bit pointer)
  uint32_t symtab;            // struct objc_symtab * (32-bit pointer)
};

struct objc_symtab_t 
{
  uint32_t sel_ref_cnt; 
  uint32_t refs;              // SEL * (32-bit pointer)
  uint16_t cls_def_cnt;
  uint16_t cat_def_cnt;
  uint32_t defs[0];           // void * (32-bit pointer) variable size
};

struct objc_class_t 
{
  uint32_t isa;               // struct objc_class * (32-bit pointer)
  uint32_t super_class;       // struct objc_class * (32-bit pointer)
  uint32_t name;              // const char * (32-bit pointer)
  int32_t version;
  int32_t info;
  int32_t instance_size;
  uint32_t ivars;             // struct objc_ivar_list * (32-bit pointer)
  uint32_t methodLists;       // struct objc_method_list ** (32-bit pointer)
  uint32_t cache;             // struct objc_cache * (32-bit pointer)
  uint32_t protocols;         // struct objc_protocol_list * (32-bit pointer)
};

struct objc_category_t 
{
  uint32_t category_name;     // char * (32-bit pointer)
  uint32_t class_name;        // char * (32-bit pointer)
  uint32_t instance_methods;	// struct objc_method_list * (32-bit pointer)
  uint32_t class_methods;     // struct objc_method_list * (32-bit pointer)
  uint32_t protocols;         // struct objc_protocol_list * (32-bit ptr)
};

struct objc_ivar_t 
{
  uint32_t ivar_name;         // char * (32-bit pointer)
  uint32_t ivar_type;         // char * (32-bit pointer)
  int32_t ivar_offset;
};

struct objc_ivar_list_t 
{
  int32_t ivar_count;
  struct objc_ivar_t ivar_list[0];  // variable length structure
};

struct objc_method_t 
{
  uint32_t method_name;       // SEL, aka struct objc_selector * (32-bit pointer)
  uint32_t method_types;      // char * (32-bit pointer)
  uint32_t method_imp;        // IMP, aka function pointer, (*IMP)(id, SEL, ...) (32-bit pointer)
};

struct objc_method_list_t 
{
  uint32_t obsolete;          // struct objc_method_list * (32-bit pointer)
  int32_t method_count;
  struct objc_method_t method_list[0];  // variable length structure
};

struct objc_protocol_t 
{
  uint32_t isa;               // struct objc_class * (32-bit pointer) 
  uint32_t protocol_name;     // char * (32-bit pointer)
  uint32_t protocol_list;     // struct objc_protocol_list * (32-bit pointer)
  uint32_t instance_methods;	// struct objc_method_description_list * (32-bit pointer)
  uint32_t class_methods;     // struct objc_method_description_list * (32-bit pointer)
};

struct objc_protocol_list_t 
{
  uint32_t next;              // struct objc_protocol_list * (32-bit pointer)
  int32_t count;
  uint32_t list[0];           // Protocol *, aka struct objc_protocol_t * (32-bit pointer)
};

struct objc_method_description_t 
{
  uint32_t name;              // SEL, aka struct objc_selector * (32-bit pointer)
  uint32_t types;             // char * (32-bit pointer)
};

struct objc_method_description_list_t 
{
  int32_t count;
  struct objc_method_description_t list[0];
};

//--------------------- ObjC2 32bit ----------------------------------------

struct class_t 
{
  uint32_t isa;               // class_t * (32-bit pointer)
  uint32_t superclass;        // class_t * (32-bit pointer)
  uint32_t cache;             // Cache (32-bit pointer)
  uint32_t vtable;            // IMP * (32-bit pointer)
  uint32_t data;              // class_ro_t * (32-bit pointer)
};

struct class_ro_t 
{
  uint32_t flags;
  uint32_t instanceStart;
  uint32_t instanceSize;
  uint32_t ivarLayout;        // const uint8_t * (32-bit pointer)
  uint32_t name;              // const char * (32-bit pointer)
  uint32_t baseMethods;       // const method_list_t * (32-bit pointer)
  uint32_t baseProtocols;     // const protocol_list_t * (32-bit pointer)
  uint32_t ivars;             // const ivar_list_t * (32-bit pointer)
  uint32_t weakIvarLayout;    // const uint8_t * (32-bit pointer)
  uint32_t baseProperties;    // const struct objc_property_list * (32-bit pointer)
};

struct method_t 
{
  uint32_t name;              // SEL (32-bit pointer)
  uint32_t types;             // const char * (32-bit pointer)
  uint32_t imp;               // IMP (32-bit pointer)
};

struct method_list_t 
{
  uint32_t entsize;
  uint32_t count;
  //struct method_t first;  These structures follow inline
};

struct ivar_list_t 
{
  uint32_t entsize;
  uint32_t count;
  // struct ivar_t first;  These structures follow inline
};

struct ivar_t 
{
  uint32_t offset;            // uintptr_t * (32-bit pointer)
  uint32_t name;              // const char * (32-bit pointer)
  uint32_t type;              // const char * (32-bit pointer)
  uint32_t alignment;
  uint32_t size;
};

struct protocol_list_t 
{
  uint32_t count;             // uintptr_t (a 32-bit value)
  // struct protocol_t * list[0];  These pointers follow inline
};

struct protocol_t 
{
  uint32_t isa;               // id * (32-bit pointer)
  uint32_t name;              // const char * (32-bit pointer)
  uint32_t protocols;         // struct protocol_list_t * (32-bit pointer)
  uint32_t instanceMethods;		// method_list_t * (32-bit pointer)
  uint32_t classMethods;      // method_list_t * (32-bit pointer)
  uint32_t optionalInstanceMethods;	// method_list_t * (32-bit pointer)
  uint32_t optionalClassMethods;	// method_list_t * (32-bit pointer)
  uint32_t instanceProperties;	// struct objc_property_list * (32-bit pointer)
};

struct objc_property_list 
{
  uint32_t entsize;
  uint32_t count;
  // struct objc_property first;  These structures follow inline
};

struct objc_property 
{
  uint32_t name;              // const char * (32-bit pointer)
  uint32_t attributes;        // const char * (32-bit pointer)
};

struct category_t 
{
  uint32_t name;              // const char * (32-bit pointer)
  uint32_t cls;               // struct class_t * (32-bit pointer)
  uint32_t instanceMethods;   // struct method_list_t * (32-bit pointer)
  uint32_t classMethods;      // struct method_list_t * (32-bit pointer)
  uint32_t protocols;         // struct protocol_list_t * (32-bit pointer)
  uint32_t instanceProperties; // struct objc_property_list * (32-bit pointer)
};

struct message_ref 
{
  uint32_t imp;               // IMP (32-bit pointer)
  uint32_t sel;               // SEL (32-bit pointer)
};

//--------------------- ObjC2 64bit ----------------------------------------

struct class64_t 
{
  uint64_t isa;               // class_t * (64-bit pointer)
  uint64_t superclass;        // class_t * (64-bit pointer)
  uint64_t cache;             // Cache (64-bit pointer)
  uint64_t vtable;            // IMP * (64-bit pointer)
  uint64_t data;              // class_ro_t * (64-bit pointer)
};

struct class64_ro_t 
{
  uint32_t flags;
  uint32_t instanceStart;
  uint32_t instanceSize;
  uint32_t reserved;
  uint64_t ivarLayout;        // const uint8_t * (64-bit pointer)
  uint64_t name;              // const char * (64-bit pointer)
  uint64_t baseMethods;       // const method_list_t * (64-bit pointer)
  uint64_t baseProtocols;     // const protocol_list_t * (64-bit pointer)
  uint64_t ivars;             // const ivar_list_t * (64-bit pointer)
  uint64_t weakIvarLayout;    // const uint8_t * (64-bit pointer)
  uint64_t baseProperties;    // const struct objc_property_list * (64-bit pointer)
};

struct method64_list_t 
{
  uint32_t entsize;
  uint32_t count;
  // struct method_t first;  These structures follow inline
};

struct method64_t 
{
  uint64_t name;              // SEL (64-bit pointer)
  uint64_t types;             // const char * (64-bit pointer)
  uint64_t imp;               // IMP (64-bit pointer)
};

struct ivar64_list_t 
{
  uint32_t entsize;
  uint32_t count;
  // struct ivar_t first;  These structures follow inline
};

struct ivar64_t 
{
  uint64_t offset;            // uintptr_t * (64-bit pointer)
  uint64_t name;              // const char * (64-bit pointer)
  uint64_t type;              // const char * (64-bit pointer)
  uint32_t alignment;
  uint32_t size;
};

struct protocol64_list_t 
{
  uint64_t count;             // uintptr_t (a 64-bit value)
  // struct protocol_t * list[0];  These pointers follow inline
};

struct protocol64_t
{
  uint64_t isa;               // id * (64-bit pointer)
  uint64_t name;              // const char * (64-bit pointer)
  uint64_t protocols;         // struct protocol_list_t * (64-bit pointer)
  uint64_t instanceMethods;		// method_list_t * (64-bit pointer)
  uint64_t classMethods;      // method_list_t * (64-bit pointer)
  uint64_t optionalInstanceMethods;	// method_list_t * (64-bit pointer)
  uint64_t optionalClassMethods;	// method_list_t * (64-bit pointer)
  uint64_t instanceProperties;	// struct objc_property_list * (64-bit pointer)
};

struct objc_property64_list 
{
  uint32_t entsize;
  uint32_t count;
  // struct objc_property first;  These structures follow inline
};

struct objc_property64 
{
  uint64_t name;              // const char * (64-bit pointer)
  uint64_t attributes;        // const char * (64-bit pointer)
};

struct category64_t
{
  uint64_t name;              // const char * (64-bit pointer)
  uint64_t cls;               // struct class_t * (64-bit pointer)
  uint64_t instanceMethods;   // struct method_list_t * (64-bit pointer)
  uint64_t classMethods;      // struct method_list_t * (64-bit pointer)
  uint64_t protocols;         // struct protocol_list_t * (64-bit pointer)
  uint64_t instanceProperties; // struct objc_property_list * (64-bit pointer)
};

struct message_ref64 
{
  uint64_t imp;               // IMP (64-bit pointer)
  uint64_t sel;               // SEL (64-bit pointer)
};

struct swift_type
{
    uint32_t flags;
    int32_t parent;
};

struct swift_type_module
{
    uint32_t flags;
    int32_t parent;
    int32_t name;
};

struct swift_vtable_descriptor_header
{
    uint32_t offset;
    uint32_t size;
};

struct swift_vtable_descriptor
{
    uint32_t flags;
    int32_t imp;
};

struct swift_type_class
{
    uint32_t flags;
    int32_t parent;
    int32_t name;
    int32_t access_function;
    int32_t field_descriptor;
    uint32_t superclass_type;
    uint32_t negative_size;
    uint32_t positive_size;
    uint32_t number_of_immediate_members;
    uint32_t number_of_fields;
    uint32_t field_offset_vector_offset;

    // optional
    int32_t resilient_superclass;
    int32_t metadataInitialization[3];
    struct swift_vtable_descriptor_header vtable;
    struct swift_vtable_descriptor methods[0];
};

struct swift_type_struct
{
    uint32_t flags;
    int32_t parent;
    int32_t name;
    int32_t access_function;
    int32_t field_descriptor;
    uint32_t number_of_fields;
    uint32_t field_offset_vector_offset;
};

#define SWIFT_VTABLE_DESCRIPTOR_MASK_KIND (0x0F)
#define SWIFT_VTABLE_DESCRIPTOR_MASK_IS_INSTANCE (0x10)
#define SWIFT_VTABLE_DESCRIPTOR_MASK_IS_DYNAMIC (0x20)

enum swift_method_kind {
    swift_method_kind_method,
    swift_method_kind_init,
    swift_method_kind_getter,
    swift_method_kind_setter,
    swift_method_kind_modifyCoroutine,
    swift_method_kind_readCoroutine,
};

#define SWIFT_CONTEXT_DESCRIPTOR_KIND_MODULE 0
#define SWIFT_CONTEXT_DESCRIPTOR_KIND_EXTENSION 1
#define SWIFT_CONTEXT_DESCRIPTOR_KIND_ANONYMOUS 2
#define SWIFT_CONTEXT_DESCRIPTOR_KIND_PROTOCOL 3
#define SWIFT_CONTEXT_DESCRIPTOR_KIND_OPAQUE_TYPE 4
#define SWIFT_CONTEXT_DESCRIPTOR_KIND_CLASS 16
#define SWIFT_CONTEXT_DESCRIPTOR_KIND_STRUCT 17
#define SWIFT_CONTEXT_DESCRIPTOR_KIND_ENUM 18
#define SWIFT_CONTEXT_DESCRIPTOR_KIND_ANY 31

enum {
    // All of these values are bit offsets or widths.
    // Generic flags build upwards from 0.
    // Type-specific flags build downwards from 15.

    /// Whether there's something unusual about how the metadata is
    /// initialized.
    ///
    /// Meaningful for all type-descriptor kinds.
    MetadataInitialization = 0,
    MetadataInitialization_width = 2,

    /// Set if the type has extended import information.
    ///
    /// If true, a sequence of strings follow the null terminator in the
    /// descriptor, terminated by an empty string (i.e. by two null
    /// terminators in a row).  See TypeImportInfo for the details of
    /// these strings and the order in which they appear.
    ///
    /// Meaningful for all type-descriptor kinds.
    HasImportInfo = 2,

    /// Set if the type descriptor has a pointer to a list of canonical
    /// prespecializations.
    HasCanonicalMetadataPrespecializations = 3,

    /// Set if the metadata contains a pointer to a layout string
    HasLayoutString = 4,

    // Type-specific flags:

    /// Set if the class is an actor.
    ///
    /// Only meaningful for class descriptors.
    Class_IsActor = 7,

    /// Set if the class is a default actor class.  Note that this is
    /// based on the best knowledge available to the class; actor
    /// classes with resilient superclassess might be default actors
    /// without knowing it.
    ///
    /// Only meaningful for class descriptors.
    Class_IsDefaultActor = 8,

    /// The kind of reference that this class makes to its resilient superclass
    /// descriptor.  A TypeReferenceKind.
    ///
    /// Only meaningful for class descriptors.
    Class_ResilientSuperclassReferenceKind = 9,
    Class_ResilientSuperclassReferenceKind_width = 3,

    /// Whether the immediate class members in this metadata are allocated
    /// at negative offsets.  For now, we don't use this.
    Class_AreImmediateMembersNegative = 12,

    /// Set if the context descriptor is for a class with resilient ancestry.
    ///
    /// Only meaningful for class descriptors.
    Class_HasResilientSuperclass = 13,

    /// Set if the context descriptor includes metadata for dynamically
    /// installing method overrides at metadata instantiation time.
    Class_HasOverrideTable = 14,

    /// Set if the context descriptor includes metadata for dynamically
    /// constructing a class's vtables at metadata instantiation time.
    ///
    /// Only meaningful for class descriptors.
    Class_HasVTable = 15,
};

enum MetadataInitializationKind {
  /// There are either no special rules for initializing the metadata
  /// or the metadata is generic.  (Genericity is set in the
  /// non-kind-specific descriptor flags.)
  NoMetadataInitialization = 0,

  /// The type requires non-trivial singleton initialization using the
  /// "in-place" code pattern.
  SingletonMetadataInitialization = 1,

  /// The type requires non-trivial singleton initialization using the
  /// "foreign" code pattern.
  ForeignMetadataInitialization = 2,

  // We only have two bits here, so if you add a third special kind,
  // include more flag bits in its out-of-line storage.
};

struct swift_field_record {
    uint32_t flags;
    int32_t name;
    int32_t fieldname;
};

struct swift_field_descriptor
{
    int32_t type_name;
    int32_t superclass;
    uint16_t kind;
    uint16_t field_record_size;
    uint32_t number_of_records;
    struct swift_field_record records[0];
};

//--------------------- Predeclarations ----------------------------------------

@interface MachOLayout (Predeclarations)

- (MVNode *)createObjCProtocolListNode:(MVNode *)parent
                               caption:(NSString *)caption
                              location:(uint32_t)location
                             protocols:(struct objc_protocol_list_t const *)objc_protocol_list_t;

- (MVNode *)createObjC2ProtocolListNode:(MVNode *)parent
                                caption:(NSString *)caption
                               location:(uint32_t)location
                              protocols:(struct protocol_list_t const *)protocol_list_t;

- (MVNode *)createObjC2Protocol64ListNode:(MVNode *)parent
                                  caption:(NSString *)caption
                                 location:(uint32_t)location
                                protocols:(struct protocol64_list_t const *)protocol64_list_t;

@end


//============================================================================
@implementation MachOLayout (ObjC)


//------------------------------------------------------------------------------
- (MVNode *)objcSectionNodeContainsRVA:(uint32_t)rva
{
  MVNode * node = [self sectionNodeContainsRVA:rva];
  // segment name must be __OBJC
  return (node && [[node.userInfo objectForKey:@"segname"] isEqualToString:@"__OBJC"] ? node: nil);
}

//------------------------------------------------------------------------------
// returns YES if has already been processed
//------------------------------------------------------------------------------
- (MVNode *)entryInSectionNode:(MVNode *)node atLocation:(uint32_t)location
{
  NSUInteger childCount = [node numberOfChildren];
  
  for (NSUInteger nchild = 0; nchild < childCount; ++nchild)
  {
    MVNode * child = [node childAtIndex:nchild];
    if (NSLocationInRange(location,child.dataRange))
    {
      NSParameterAssert(location == child.dataRange.location); // check for perfect match
      return child;
    }
  }
  return nil;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCCFStringsNode:(MVNode *)parent
                            caption:(NSString *)caption
                           location:(uint32_t)location
                             length:(uint32_t)length
{
  struct cfstring_t
  {
    uint32_t ptr;
    uint32_t data;
    uint32_t cstr;
    uint32_t size;
  };
  
  MVNodeSaver nodeSaver;
  MVNode * node = [parent insertChildWithDetails:caption location:location length:length saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  while (NSMaxRange(range) < location + length)
  {
    MATCH_STRUCT(cfstring_t,NSMaxRange(range))
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;

    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"CFString Ptr"
                           :[self findSymbolAtRVA:cfstring_t->ptr]];

    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@""
                           :[self findSymbolAtRVA:cfstring_t->data]];

    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"String"
                           :(symbolName = [self findSymbolAtRVA:cfstring_t->cstr])];

    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Size"
                           :[NSString stringWithFormat:@"%u",cfstring_t->size]];
    
    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCCFStrings64Node:(MVNode *)parent
                              caption:(NSString *)caption
                             location:(uint32_t)location
                               length:(uint32_t)length
{
  struct cfstring64_t
  {
    uint64_t ptr;
    uint64_t data;
    uint64_t cstr;
    uint64_t size;
  };
  
  MVNodeSaver nodeSaver;
  MVNode * node = [parent insertChildWithDetails:caption location:location length:length saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  while (NSMaxRange(range) < location + length)
  {
    MATCH_STRUCT(cfstring64_t,NSMaxRange(range))
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"CFString Ptr"
                           :[self findSymbolAtRVA64:cfstring64_t->ptr]];
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@""
                           :[self findSymbolAtRVA64:cfstring64_t->data]];
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"String"
                           :(symbolName = [self findSymbolAtRVA64:cfstring64_t->cstr])];
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Size"
                           :[NSString stringWithFormat:@"%qu",cfstring64_t->size]];
    
    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createSwiftTypes64Node:(MVNode *)parent
                           caption:(NSString *)caption
                          location:(uint32_t)location
                            length:(uint32_t)length
{
    MVNodeSaver nodeSaver;
    MVNode * node = [parent insertChildWithDetails:caption location:location length:length saver:nodeSaver];

    NSRange range = NSMakeRange(location,0);
    NSString * lastReadHex;

    while (NSMaxRange(range) < location + length)
    {
        uint64_t offset = [dataController read_uint32_offset:range lastReadHex:&lastReadHex];
        uint64_t address = [self fileOffsetToRVA64:offset];

        NSString * caption = [self findSymbolAtRVA64:address];

        [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                               :lastReadHex
                               :@"Pointer"
                               :caption];
        [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];

        MVNode * childNode = nil;

        if (address && (childNode = [self sectionNodeContainsRVA64:address]))
        {
            uint32_t location = [self RVA64ToFileOffset:address];
            MATCH_STRUCT(swift_type,location)
            [self createSwiftType64Node:childNode
                                caption:caption
                               location:location
                              swiftType:swift_type];
        }
    }

    return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCImageInfoNode:(MVNode *)parent
                            caption:(NSString *)caption
                           location:(uint32_t)location
                             length:(uint32_t)length
{
  MVNodeSaver nodeSaver;
  MVNode * node = [parent insertChildWithDetails:caption location:location length:length saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  MATCH_STRUCT(objc_image_info,location)
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Version"
                         :[NSString stringWithFormat:@"%u",objc_image_info->version]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Flags"
                         :@""];
  
  if (objc_image_info->flags & OBJC_IMAGE_IS_REPLACEMENT) [node.details appendRow:@"":@"":@"0x1":@"OBJC_IMAGE_IS_REPLACEMENT"];
  if (objc_image_info->flags & OBJC_IMAGE_SUPPORTS_GC)    [node.details appendRow:@"":@"":@"0x2":@"OBJC_IMAGE_SUPPORTS_GC"];
  if (objc_image_info->flags & OBJC_IMAGE_GC_ONLY)        [node.details appendRow:@"":@"":@"0x4":@"OBJC_IMAGE_GC_ONLY"];
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCVariablesNode:(MVNode *)parent
                            caption:(NSString *)caption
                           location:(uint32_t)location
                              ivars:(struct objc_ivar_list_t const *)objc_ivar_list_t
{
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"Objc Variable List: " stringByAppendingString:caption] 
                               location:location 
                                 length:sizeof(struct objc_ivar_list_t) + objc_ivar_list_t->ivar_count*sizeof(struct objc_ivar_t)
                                  saver:nodeSaver];
  
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;

  [dataController read_int32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Count"
                         :[NSString stringWithFormat:@"%i",objc_ivar_list_t->ivar_count]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],
                              MVUnderlineAttributeName,@"YES",nil];
  
  for (int32_t nivar = 0; nivar < objc_ivar_list_t->ivar_count; ++nivar)
  {
    struct objc_ivar_t const * objc_ivar_t = &objc_ivar_list_t->ivar_list[nivar];
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Name"
                           :(symbolName = [self findSymbolAtRVA:objc_ivar_t->ivar_name])];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Type"
                           :[self findSymbolAtRVA:objc_ivar_t->ivar_type]];
    
    [dataController read_int32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Offset"
                           :[NSString stringWithFormat:@"%u",objc_ivar_t->ivar_offset]];
    
    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCMethodsNode:(MVNode *)parent
                          caption:(NSString *)caption
                         location:(uint32_t)location
                          methods:(struct objc_method_list_t const *)objc_method_list_t
{
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"Objc Method List: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct objc_method_list_t) + objc_method_list_t->method_count*sizeof(struct objc_method_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Obsolete"
                         :[NSString stringWithFormat:@"0x%X",objc_method_list_t->obsolete]];

  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],nil];
  
  [dataController read_int32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Count"
                         :[NSString stringWithFormat:@"%i",objc_method_list_t->method_count]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],
                              MVUnderlineAttributeName,@"YES",nil];
  
  for (int32_t nmeth = 0; nmeth < objc_method_list_t->method_count; ++nmeth)
  {
    struct objc_method_t const * objc_method_t = &objc_method_list_t->method_list[nmeth];
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Name"
                           :(symbolName = [self findSymbolAtRVA:objc_method_t->method_name])];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Types"
                           :[self findSymbolAtRVA:objc_method_t->method_types]];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"IMP (Function Pointer)"
                           :[self findSymbolAtRVA:objc_method_t->method_imp]];
    
    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCMethodDescrsNode:(MVNode *)parent
                               caption:(NSString *)caption
                              location:(uint32_t)location
                             methodDescrs:(struct objc_method_description_list_t const *)objc_method_description_list_t
{
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"Objc Method Descr List: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct objc_method_description_list_t) + objc_method_description_list_t->count*sizeof(struct objc_method_description_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_int32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Count"
                         :[NSString stringWithFormat:@"%i",objc_method_description_list_t->count]];

  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],
                              MVUnderlineAttributeName,@"YES",nil];
  
  for (int32_t ndescr = 0; ndescr < objc_method_description_list_t->count; ++ndescr)
  {
    struct objc_method_description_t const * objc_method_description_t = &objc_method_description_list_t->list[ndescr];
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Name"
                           :(symbolName = [self findSymbolAtRVA:objc_method_description_t->name])];

    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Types"
                           :[self findSymbolAtRVA:objc_method_description_t->types]];
    
    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
  }
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCProtocolNode:(MVNode *)parent
                           caption:(NSString *)caption
                          location:(uint32_t)location
                          protocol:(struct objc_protocol_t const *)objc_protocol_t
{
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"Objc Protocol: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct objc_protocol_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"ISA"
                         :[self findSymbolAtRVA:objc_protocol_t->isa]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Name"
                         :[self findSymbolAtRVA:objc_protocol_t->protocol_name]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Protocol List"
                         :[self findSymbolAtRVA:objc_protocol_t->protocol_list]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Method Descrs"
                         :[self findSymbolAtRVA:objc_protocol_t->instance_methods]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Class Method Descrs"
                         :[self findSymbolAtRVA:objc_protocol_t->class_methods]];
  
  MVNode * childNode = nil;
  
  // embedded protocol lists
  if (objc_protocol_t->protocol_list && (childNode = [self objcSectionNodeContainsRVA:objc_protocol_t->protocol_list]))
  {
    uint32_t location = [self RVAToFileOffset:objc_protocol_t->protocol_list];
    NSString * caption = [self findSymbolAtRVA:objc_protocol_t->protocol_list];
    MATCH_STRUCT(objc_protocol_list_t,location)
    [self createObjCProtocolListNode:childNode
                             caption:caption
                            location:location
                           protocols:objc_protocol_list_t];
  }
  
  // instance method descriptors
  if (objc_protocol_t->instance_methods && (childNode = [self objcSectionNodeContainsRVA:objc_protocol_t->instance_methods]))
  {
    uint32_t location = [self RVAToFileOffset:objc_protocol_t->instance_methods];
    NSString * caption = [self findSymbolAtRVA:objc_protocol_t->instance_methods];
    MATCH_STRUCT(objc_method_description_list_t,location)
    [self createObjCMethodDescrsNode:childNode
                             caption:caption
                            location:location
                        methodDescrs:objc_method_description_list_t];
  }
  
  // class method descriptors
  if (objc_protocol_t->class_methods && (childNode = [self objcSectionNodeContainsRVA:objc_protocol_t->class_methods]))
  {
    uint32_t location = [self RVAToFileOffset:objc_protocol_t->class_methods];
    NSString * caption = [self findSymbolAtRVA:objc_protocol_t->class_methods];
    MATCH_STRUCT(objc_method_description_list_t,location)
    [self createObjCMethodDescrsNode:childNode
                             caption:caption
                            location:location
                        methodDescrs:objc_method_description_list_t];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCProtocolListNode:(MVNode *)parent
                               caption:(NSString *)caption
                              location:(uint32_t)location
                             protocols:(struct objc_protocol_list_t const *)objc_protocol_list_t
{
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"Objc Protocol List: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct objc_protocol_list_t) + objc_protocol_list_t->count*sizeof(uint32_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Next"
                         :[self findSymbolAtRVA:objc_protocol_list_t->next]];

  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],nil];
  
  [dataController read_int32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Count"
                         :[NSString stringWithFormat:@"%i",objc_protocol_list_t->count]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],
                              MVUnderlineAttributeName,@"YES",nil];

  MVNode * childNode = nil;

  for (int32_t nprot = 0; nprot < objc_protocol_list_t->count; ++nprot)
  {
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :[NSString stringWithFormat:@"Protocol[%i]",nprot]
                           :[self findSymbolAtRVA:objc_protocol_list_t->list[nprot]]];
    
    if (objc_protocol_list_t->list[nprot] && (childNode = [self objcSectionNodeContainsRVA:objc_protocol_list_t->list[nprot]]))
    {
      uint32_t location = [self RVAToFileOffset:objc_protocol_list_t->list[nprot]];
      NSString * caption = [self findSymbolAtRVA:objc_protocol_list_t->list[nprot]];
      MATCH_STRUCT(objc_protocol_t,location)
      [self createObjCProtocolNode:childNode
                           caption:caption
                          location:location
                          protocol:objc_protocol_t];
    }
  }
  
  // next protocol list
  if (objc_protocol_list_t->next && (childNode = [self objcSectionNodeContainsRVA:objc_protocol_list_t->next]))
  {
    uint32_t location = [self RVAToFileOffset:objc_protocol_list_t->next];
    NSString * caption = [self findSymbolAtRVA:objc_protocol_list_t->next];
    MATCH_STRUCT(objc_protocol_list_t,location)
    [self createObjCProtocolListNode:childNode
                             caption:caption
                            location:location
                           protocols:objc_protocol_list_t];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCClassNode:(MVNode *)parent
                        caption:(NSString *)caption
                       location:(uint32_t)location
                      objcClass:(struct objc_class_t const *)objc_class_t
{
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"Objc Class: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct objc_class_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"ISA"
                         :[self findSymbolAtRVA:objc_class_t->isa]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Super Class"
                         :[self findSymbolAtRVA:objc_class_t->super_class]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Name"
                         :[self findSymbolAtRVA:objc_class_t->name]];
  
  [dataController read_int32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Version"
                         :[NSString stringWithFormat:@"%i", objc_class_t->version]];
  
  [dataController read_int32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Info"
                         :@""];
   
  if (objc_class_t->info &     0x1) [node.details appendRow:@"":@"":@"    1":@"CLS_CLASS"];
  if (objc_class_t->info &     0x2) [node.details appendRow:@"":@"":@"    2":@"CLS_META"];
  if (objc_class_t->info &     0x4) [node.details appendRow:@"":@"":@"    4":@"CLS_INITIALIZED"];
  if (objc_class_t->info &     0x8) [node.details appendRow:@"":@"":@"    8":@"CLS_POSING"];
  if (objc_class_t->info &    0x10) [node.details appendRow:@"":@"":@"   10":@"CLS_MAPPED"];
  if (objc_class_t->info &    0x20) [node.details appendRow:@"":@"":@"   20":@"CLS_FLUSH_CACHE"];
  if (objc_class_t->info &    0x40) [node.details appendRow:@"":@"":@"   40":@"CLS_GROW_CACHE"];
  if (objc_class_t->info &    0x80) [node.details appendRow:@"":@"":@"   80":@"CLS_NEED_BIND"];
  if (objc_class_t->info &   0x100) [node.details appendRow:@"":@"":@"  100":@"CLS_METHOD_ARRAY"];
  if (objc_class_t->info &   0x200) [node.details appendRow:@"":@"":@"  200":@"CLS_JAVA_HYBRID"];
  if (objc_class_t->info &   0x400) [node.details appendRow:@"":@"":@"  400":@"CLS_JAVA_CLASS"];
  if (objc_class_t->info &   0x800) [node.details appendRow:@"":@"":@"  800":@"CLS_INITIALIZING"];
  if (objc_class_t->info &  0x1000) [node.details appendRow:@"":@"":@" 1000":@"CLS_FROM_BUNDLE"];
  if (objc_class_t->info &  0x2000) [node.details appendRow:@"":@"":@" 2000":@"CLS_HAS_CXX_STRUCTORS"];
  if (objc_class_t->info &  0x4000) [node.details appendRow:@"":@"":@" 4000":@"CLS_NO_METHOD_ARRAY"];
  if (objc_class_t->info &  0x8000) [node.details appendRow:@"":@"":@" 8000":@"CLS_HAS_LOAD_METHOD"];
  if (objc_class_t->info & 0x10000) [node.details appendRow:@"":@"":@"10000":@"CLS_CONSTRUCTING"];
  if (objc_class_t->info & 0x20000) [node.details appendRow:@"":@"":@"20000":@"CLS_EXT"];


  [dataController read_int32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Size"
                         :[NSString stringWithFormat:@"%i", objc_class_t->instance_size]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Vars"
                         :[self findSymbolAtRVA:objc_class_t->ivars]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Method Lists"
                         :[self findSymbolAtRVA:objc_class_t->methodLists]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Cache"
                         :[self findSymbolAtRVA:objc_class_t->cache]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Protocols"
                         :[self findSymbolAtRVA:objc_class_t->protocols]];

  MVNode * childNode = nil;
  
  // Meta Classes
  if (objc_class_t->isa && (childNode = [self objcSectionNodeContainsRVA:objc_class_t->isa])
      && (objc_class_t->info & 0x1) == 0x1)
  {
    uint32_t location = [self RVAToFileOffset:objc_class_t->isa];
    NSString * caption = [self findSymbolAtRVA:objc_class_t->isa];
    MATCH_STRUCT(objc_class_t,location)
    [self createObjCClassNode:childNode
                      caption:caption
                     location:location
                    objcClass:objc_class_t];
  }
  
  // Instance Variables
  if (objc_class_t->ivars && (childNode = [self objcSectionNodeContainsRVA:objc_class_t->ivars]))
  {
    uint32_t location = [self RVAToFileOffset:objc_class_t->ivars];
    NSString * caption = [self findSymbolAtRVA:objc_class_t->ivars];
    MATCH_STRUCT (objc_ivar_list_t,location)
    [self createObjCVariablesNode:childNode
                          caption:caption
                         location:location
                            ivars:objc_ivar_list_t];
  }
  
  // Methods
  if (objc_class_t->methodLists && (childNode = [self objcSectionNodeContainsRVA:objc_class_t->methodLists]))
  {
    uint32_t location = [self RVAToFileOffset:objc_class_t->methodLists];
    NSString * caption = [self findSymbolAtRVA:objc_class_t->methodLists];
    MATCH_STRUCT (objc_method_list_t,location)
    [self createObjCMethodsNode:childNode
                        caption:caption
                       location:location
                        methods:objc_method_list_t];
  }
  
  // Protocols
  if (objc_class_t->protocols && (childNode = [self objcSectionNodeContainsRVA:objc_class_t->protocols]))
  {
    uint32_t location = [self RVAToFileOffset:objc_class_t->protocols];
    NSString * caption = [self findSymbolAtRVA:objc_class_t->protocols];
    MATCH_STRUCT (objc_protocol_list_t,location)
    [self createObjCProtocolListNode:childNode
                             caption:caption
                            location:location
                           protocols:objc_protocol_list_t];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCCategoryNode:(MVNode *)parent
                           caption:(NSString *)caption
                          location:(uint32_t)location
                      objcCategory:(struct objc_category_t const *)objc_category_t
{
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"Objc Category: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct objc_category_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  NSString * className;
  NSString * categoryName;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Name"
                         :categoryName = [self findSymbolAtRVA:objc_category_t->category_name]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Class Name"
                         :className = [self findSymbolAtRVA:objc_category_t->class_name]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Methods"
                         :[NSString stringWithFormat:@"0x%X",objc_category_t->instance_methods]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Class Methods"
                         :[NSString stringWithFormat:@"0x%X",objc_category_t->class_methods]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Protocols"
                         :[NSString stringWithFormat:@"0x%X",objc_category_t->protocols]];
  

  node.caption = [NSString stringWithFormat:@"%@ [%@ %@]", node.caption, className, categoryName];
  
  
  MVNode * childNode = nil;
  
  // Instance Methods
  if (objc_category_t->instance_methods && (childNode = [self objcSectionNodeContainsRVA:objc_category_t->instance_methods]))
  {
    uint32_t location = [self RVAToFileOffset:objc_category_t->instance_methods];
    NSString * caption = [self findSymbolAtRVA:objc_category_t->instance_methods];
    MATCH_STRUCT(objc_method_list_t,location)
    [self createObjCMethodsNode:childNode
                        caption:caption
                       location:location
                        methods:objc_method_list_t];
  }
  
  // Class Methods
  if (objc_category_t->class_methods && (childNode = [self objcSectionNodeContainsRVA:objc_category_t->class_methods]))
  {
    uint32_t location = [self RVAToFileOffset:objc_category_t->class_methods];
    NSString * caption = [self findSymbolAtRVA:objc_category_t->class_methods];
    MATCH_STRUCT(objc_method_list_t,location)
    [self createObjCMethodsNode:childNode
                        caption:caption
                       location:location
                        methods:objc_method_list_t];
  }

  // Protocols
  if (objc_category_t->protocols && (childNode = [self objcSectionNodeContainsRVA:objc_category_t->protocols]))
  {
    uint32_t location = [self RVAToFileOffset:objc_category_t->protocols];
    NSString * caption = [self findSymbolAtRVA:objc_category_t->protocols];
    MATCH_STRUCT (objc_protocol_list_t,location)
    [self createObjCProtocolListNode:childNode
                             caption:caption
                            location:location
                           protocols:objc_protocol_list_t];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCSymtabNode:(MVNode *)parent
                         caption:(NSString *)caption
                        location:(uint32_t)location
                      objcSymtab:(struct objc_symtab_t const *)objc_symtab_t
{
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"Objc Symtab: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct objc_symtab_t) + (objc_symtab_t->cls_def_cnt + objc_symtab_t->cat_def_cnt)*sizeof(uint32_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Selector Reference Count"
                         :[NSString stringWithFormat:@"%u", objc_symtab_t->sel_ref_cnt]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"References"
                         :[self findSymbolAtRVA:objc_symtab_t->refs]];
  
  [dataController read_uint16:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Class Definition Count"
                         :[NSString stringWithFormat:@"%u", objc_symtab_t->cls_def_cnt]];
  
  [dataController read_uint16:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Category Definition Count"
                         :[NSString stringWithFormat:@"%u", objc_symtab_t->cat_def_cnt]];
  
  // processing definitions
  for (uint32_t ndef = 0; ndef < objc_symtab_t->cls_def_cnt + objc_symtab_t->cat_def_cnt; ++ndef)
  {
    uint32_t location = [self RVAToFileOffset:objc_symtab_t->defs[ndef]];
    NSString * caption = [self findSymbolAtRVA:objc_symtab_t->defs[ndef]];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :[NSString stringWithFormat:@"Definition[%u]",ndef]
                           :caption];
    
    MVNode * childNode = [self objcSectionNodeContainsRVA:objc_symtab_t->defs[ndef]];
    if (childNode)
    {
      // Class Definitions
      if (ndef < objc_symtab_t->cls_def_cnt)
      {
        MATCH_STRUCT(objc_class_t,location)
        [self createObjCClassNode:childNode
                          caption:caption
                         location:location
                        objcClass:objc_class_t];
      }
      // Category Definitions
      else
      {
        MATCH_STRUCT(objc_category_t,location)
        [self createObjCCategoryNode:childNode
                             caption:caption
                            location:location
                        objcCategory:objc_category_t];
      }
    }
  }
  
  return node;
  
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCModulesNode:(MVNode *)parent
                          caption:(NSString *)caption
                         location:(uint32_t)location
                           length:(uint32_t)length
{
  MVNodeSaver nodeSaver;
  MVNode * node = [parent insertChildWithDetails:caption location:location length:length saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  while (NSMaxRange(range) < location + length)
  {
    MATCH_STRUCT(objc_module_t,NSMaxRange(range))
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Version"
                           :[NSString stringWithFormat:@"%u", objc_module_t->version]];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Size"
                           :[NSString stringWithFormat:@"%u", objc_module_t->size]];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Name"
                           :(symbolName = [self findSymbolAtRVA:objc_module_t->name])];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Symtab"
                           :[self findSymbolAtRVA:objc_module_t->symtab]];

    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
    
    MVNode * childNode = nil;
    
    // symbol table
    if (objc_module_t->symtab && (childNode = [self objcSectionNodeContainsRVA:objc_module_t->symtab]))
    {
      uint32_t location = [self RVAToFileOffset:objc_module_t->symtab];
      NSString * caption = [self findSymbolAtRVA:objc_module_t->symtab];
      MATCH_STRUCT(objc_symtab_t,location)
      [self createObjCSymtabNode:childNode
                         caption:caption
                        location:location
                      objcSymtab:objc_symtab_t];
    }
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCClassExtNode:(MVNode *)parent
                           caption:(NSString *)caption
                          location:(uint32_t)location
                            length:(uint32_t)length
{
  MVNodeSaver nodeSaver;
  MVNode * node = [parent insertChildWithDetails:caption location:location length:length saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  while (NSMaxRange(range) < location + length)
  {
    uint32_t value1 = [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Size"
                           :[NSString stringWithFormat:@"%u", value1]];
    
    uint32_t value2 = [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@""
                           :[NSString stringWithFormat:@"%u", value2]];
    
    uint32_t propertyList = [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Property List"
                           :[NSString stringWithFormat:@"0x%X", propertyList]];
    
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
    
    MVNode * childNode = nil;
    
    // Instance Properties
    if (propertyList && (childNode = [self sectionNodeContainsRVA:propertyList]))
    {
      uint32_t location = [self RVAToFileOffset:propertyList];
      NSString * caption = [self findSymbolAtRVA:propertyList];
      MATCH_STRUCT(objc_property_list,location)
      [self createObjC2PropertyListNode:childNode
                                caption:caption
                               location:location
                             properties:objc_property_list];
    }
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjCProtocolExtNode:(MVNode *)parent
                              caption:(NSString *)caption
                             location:(uint32_t)location
                               length:(uint32_t)length
{
  MVNodeSaver nodeSaver;
  MVNode * node = [parent insertChildWithDetails:caption location:location length:length saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  while (NSMaxRange(range) < location + length)
  {
    uint32_t value1 = [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Size"
                           :[NSString stringWithFormat:@"%u", value1]];
    
    uint32_t value2 = [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Method Descrs"
                           :[NSString stringWithFormat:@"0x%X", value2]];
    
    uint32_t value3 = [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@""
                           :[NSString stringWithFormat:@"%u", value3]];

    uint32_t value4 = [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@""
                           :[NSString stringWithFormat:@"%u", value4]];

    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
    
    MVNode * childNode = nil;
    
    // instance method descriptors
    if (value2 && (childNode = [self objcSectionNodeContainsRVA:value2]))
    {
      uint32_t location = [self RVAToFileOffset:value2];
      NSString * caption = [self findSymbolAtRVA:value2];
      MATCH_STRUCT(objc_method_description_list_t,location)
      [self createObjCMethodDescrsNode:childNode
                               caption:caption
                              location:location
                          methodDescrs:objc_method_description_list_t];
    }
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2PointerListNode:(MVNode *)parent
                               caption:(NSString *)caption
                              location:(uint32_t)location
                                length:(uint32_t)length
                              pointers:(PointerVector &)pointers
{
  MVNodeSaver nodeSaver;
  MVNode * node = [parent insertChildWithDetails:caption location:location length:length saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  while (NSMaxRange(range) < location + length)
  {
    // accumulate search info
    NSString * symbolName = nil;
    
    uint32_t rva = [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Pointer"
                           :(symbolName = [self findSymbolAtRVA:rva])];
    
    [node.details setAttributes:MVMetaDataAttributeName,symbolName,nil];
    
    pointers.push_back(rva);
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2Pointer64ListNode:(MVNode *)parent
                                 caption:(NSString *)caption
                                location:(uint32_t)location
                                  length:(uint32_t)length
                                pointers:(Pointer64Vector &)pointers
{
  MVNodeSaver nodeSaver;
  MVNode * node = [parent insertChildWithDetails:caption location:location length:length saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  while (NSMaxRange(range) < location + length)
  {
    // accumulate search info
    NSString * symbolName = nil;

    uint64_t rva64 = [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Pointer"
                           :(symbolName = [self findSymbolAtRVA64:rva64])];
    
    [node.details setAttributes:MVMetaDataAttributeName,symbolName,nil];
    
    pointers.push_back(rva64);
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2MsgRefsNode:(MVNode *)parent
                           caption:(NSString *)caption
                          location:(uint32_t)location
                            length:(uint32_t)length
{
  MVNodeSaver nodeSaver;
  MVNode * node = [parent insertChildWithDetails:caption location:location length:length saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  while (NSMaxRange(range) < location + length)
  {
    MATCH_STRUCT(message_ref,NSMaxRange(range))
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"IMP"
                           :[self findSymbolAtRVA:message_ref->imp]];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"SEL"
                           :(symbolName = [self findSymbolAtRVA:message_ref->sel])];
    
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2MsgRefs64Node:(MVNode *)parent
                             caption:(NSString *)caption
                            location:(uint32_t)location
                              length:(uint32_t)length
{
  MVNodeSaver nodeSaver;
  MVNode * node = [parent insertChildWithDetails:caption location:location length:length saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  while (NSMaxRange(range) < location + length)
  {
    MATCH_STRUCT(message_ref64,NSMaxRange(range))
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;

    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"IMP"
                           :[self findSymbolAtRVA64:message_ref64->imp]];
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"SEL"
                           :(symbolName = [self findSymbolAtRVA64:message_ref64->sel])];
    
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2MethodListNode:(MVNode *)parent
                              caption:(NSString *)caption
                             location:(uint32_t)location
                              methods:(struct method_list_t const *)method_list_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Method List: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct method_list_t) + method_list_t->count*sizeof(struct method_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Entry Size"
                         :[NSString stringWithFormat:@"%u",method_list_t->entsize]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],nil];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Count"
                         :[NSString stringWithFormat:@"%u",method_list_t->count]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],
                              MVUnderlineAttributeName,@"YES",nil];
  
  for (uint32_t nmeth = 0; nmeth < method_list_t->count; ++nmeth)
  {
    MATCH_STRUCT(method_t,NSMaxRange(range))
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Name"
                           :(symbolName = [self findSymbolAtRVA:method_t->name])];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Types"
                           :[self findSymbolAtRVA:method_t->types]];

    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Implementation"
                           :[self findSymbolAtRVA:method_t->imp]];
    
    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2Method64ListNode:(MVNode *)parent
                                caption:(NSString *)caption
                               location:(uint32_t)location
                                methods:(struct method64_list_t const *)method64_list_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Method64 List: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct method64_list_t) + method64_list_t->count*sizeof(struct method64_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Entry Size"
                         :[NSString stringWithFormat:@"%u",method64_list_t->entsize]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],nil];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Count"
                         :[NSString stringWithFormat:@"%u",method64_list_t->count]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],
                              MVUnderlineAttributeName,@"YES",nil];
  
  for (uint32_t nmeth = 0; nmeth < method64_list_t->count; ++nmeth)
  {
    MATCH_STRUCT(method64_t,NSMaxRange(range))
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Name"
                           :(symbolName = [self findSymbolAtRVA64:method64_t->name])];
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Types"
                           :[self findSymbolAtRVA64:method64_t->types]];
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Implementation"
                           :[self findSymbolAtRVA64:method64_t->imp]];
    
    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2PropertyListNode:(MVNode *)parent
                                caption:(NSString *)caption
                               location:(uint32_t)location
                             properties:(struct objc_property_list const *)objc_property_list
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Property List: " stringByAppendingString:caption]
                               location:location
                                 length:sizeof(struct objc_property_list) + objc_property_list->count*sizeof(struct objc_property)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Entry Size"
                         :[NSString stringWithFormat:@"%u",objc_property_list->entsize]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],nil];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Count"
                         :[NSString stringWithFormat:@"%u",objc_property_list->count]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],
                              MVUnderlineAttributeName,@"YES",nil];
  
  for (uint32_t nprop = 0; nprop < objc_property_list->count; ++nprop)
  {
    MATCH_STRUCT(objc_property,NSMaxRange(range))
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Name"
                           :(symbolName = [self findSymbolAtRVA:objc_property->name])];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Attributes"
                           :[self findSymbolAtRVA:objc_property->attributes]];

    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2Property64ListNode:(MVNode *)parent
                                  caption:(NSString *)caption
                                 location:(uint32_t)location
                               properties:(struct objc_property64_list const *)objc_property64_list
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Property64 List: " stringByAppendingString:caption]
                               location:location
                                 length:sizeof(struct objc_property64_list) + objc_property64_list->count*sizeof(struct objc_property64)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Entry Size"
                         :[NSString stringWithFormat:@"%u",objc_property64_list->entsize]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],nil];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Count"
                         :[NSString stringWithFormat:@"%u",objc_property64_list->count]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],
                              MVUnderlineAttributeName,@"YES",nil];
  
  for (uint32_t nprop = 0; nprop < objc_property64_list->count; ++nprop)
  {
    MATCH_STRUCT(objc_property64,NSMaxRange(range))
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Name"
                           :(symbolName = [self findSymbolAtRVA64:objc_property64->name])];
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Attributes"
                           :[self findSymbolAtRVA64:objc_property64->attributes]];

    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
  }
  
  return  node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2ProtocolNode:(MVNode *)parent
                            caption:(NSString *)caption
                           location:(uint32_t)location
                           protocol:(struct protocol_t const *)protocol_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Protocol: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct protocol_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"ISA"
                         :[self findSymbolAtRVA:protocol_t->isa]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Name"
                         :[self findSymbolAtRVA:protocol_t->name]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Protocols"
                         :[self findSymbolAtRVA:protocol_t->protocols]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Methods"
                         :[self findSymbolAtRVA:protocol_t->instanceMethods]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Class Methods"
                         :[self findSymbolAtRVA:protocol_t->classMethods]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Optional Inst Methods"
                         :[self findSymbolAtRVA:protocol_t->optionalInstanceMethods]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Optional Class Methods"
                         :[self findSymbolAtRVA:protocol_t->optionalClassMethods]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Properties"
                         :[self findSymbolAtRVA:protocol_t->instanceProperties]];

  MVNode * childNode = nil;
  
  // Protocols
  if (protocol_t->protocols && (childNode = [self sectionNodeContainsRVA:protocol_t->protocols]))
  {
    uint32_t location = [self RVAToFileOffset:protocol_t->protocols];
    NSString * caption = [self findSymbolAtRVA:protocol_t->protocols];
    MATCH_STRUCT(protocol_list_t,location)
    [self createObjC2ProtocolListNode:childNode
                              caption:caption
                             location:location
                            protocols:protocol_list_t];
  }
  
  // Instance Methods
  if (protocol_t->instanceMethods && (childNode = [self sectionNodeContainsRVA:protocol_t->instanceMethods]))
  {
    uint32_t location = [self RVAToFileOffset:protocol_t->instanceMethods];
    NSString * caption = [self findSymbolAtRVA:protocol_t->instanceMethods];
    MATCH_STRUCT(method_list_t,location)
    [self createObjC2MethodListNode:childNode
                            caption:caption
                           location:location
                            methods:method_list_t];
  }
  
  // Class Methods
  if (protocol_t->classMethods && (childNode = [self sectionNodeContainsRVA:protocol_t->classMethods]))
  {
    uint32_t location = [self RVAToFileOffset:protocol_t->classMethods];
    NSString * caption = [self findSymbolAtRVA:protocol_t->classMethods];
    MATCH_STRUCT(method_list_t,location)
    [self createObjC2MethodListNode:childNode
                            caption:caption
                           location:location
                            methods:method_list_t];
  }

  // Optional Instance Methods
  if (protocol_t->optionalInstanceMethods && (childNode = [self sectionNodeContainsRVA:protocol_t->optionalInstanceMethods]))
  {
    uint32_t location = [self RVAToFileOffset:protocol_t->optionalInstanceMethods];
    NSString * caption = [self findSymbolAtRVA:protocol_t->optionalInstanceMethods];
    MATCH_STRUCT(method_list_t,location)
    [self createObjC2MethodListNode:childNode
                            caption:caption
                           location:location
                            methods:method_list_t];
  }

  // Optional Class Methods
  if (protocol_t->optionalClassMethods && (childNode = [self sectionNodeContainsRVA:protocol_t->optionalClassMethods]))
  {
    uint32_t location = [self RVAToFileOffset:protocol_t->optionalClassMethods];
    NSString * caption = [self findSymbolAtRVA:protocol_t->optionalClassMethods];
    MATCH_STRUCT(method_list_t,location)
    [self createObjC2MethodListNode:childNode
                            caption:caption
                           location:location
                            methods:method_list_t];
  }
  
  // Instance Properties
  if (protocol_t->instanceProperties && (childNode = [self sectionNodeContainsRVA:protocol_t->instanceProperties]))
  {
    uint32_t location = [self RVAToFileOffset:protocol_t->instanceProperties];
    NSString * caption = [self findSymbolAtRVA:protocol_t->instanceProperties];
    MATCH_STRUCT(objc_property_list,location)
    [self createObjC2PropertyListNode:childNode
                              caption:caption
                             location:location
                           properties:objc_property_list];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2Protocol64Node:(MVNode *)parent
                              caption:(NSString *)caption
                             location:(uint32_t)location
                             protocol:(struct protocol64_t const *)protocol64_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Protocol64: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct protocol64_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"ISA"
                         :[self findSymbolAtRVA64:protocol64_t->isa]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Name"
                         :[self findSymbolAtRVA64:protocol64_t->name]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Protocols"
                         :[self findSymbolAtRVA64:protocol64_t->protocols]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Methods"
                         :[self findSymbolAtRVA64:protocol64_t->instanceMethods]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Class Methods"
                         :[self findSymbolAtRVA64:protocol64_t->classMethods]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Optional Inst Methods"
                         :[self findSymbolAtRVA64:protocol64_t->optionalInstanceMethods]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Optional Class Methods"
                         :[self findSymbolAtRVA64:protocol64_t->optionalClassMethods]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Properties"
                         :[self findSymbolAtRVA64:protocol64_t->instanceProperties]];
  
  MVNode * childNode = nil;
  
  // Protocols
  if (protocol64_t->protocols && (childNode = [self sectionNodeContainsRVA64:protocol64_t->protocols]))
  {
    uint32_t location = [self RVA64ToFileOffset:protocol64_t->protocols];
    NSString * caption = [self findSymbolAtRVA64:protocol64_t->protocols];
    MATCH_STRUCT(protocol64_list_t,location)
    [self createObjC2Protocol64ListNode:childNode
                                caption:caption
                               location:location
                              protocols:protocol64_list_t];
  }
  
  // Instance Methods
  if (protocol64_t->instanceMethods && (childNode = [self sectionNodeContainsRVA64:protocol64_t->instanceMethods]))
  {
    uint32_t location = [self RVA64ToFileOffset:protocol64_t->instanceMethods];
    NSString * caption = [self findSymbolAtRVA64:protocol64_t->instanceMethods];
    MATCH_STRUCT(method64_list_t,location)
    [self createObjC2Method64ListNode:childNode
                              caption:caption
                             location:location
                              methods:method64_list_t];
  }
  
  // Class Methods
  if (protocol64_t->classMethods && (childNode = [self sectionNodeContainsRVA64:protocol64_t->classMethods]))
  {
    uint32_t location = [self RVA64ToFileOffset:protocol64_t->classMethods];
    NSString * caption = [self findSymbolAtRVA64:protocol64_t->classMethods];
    MATCH_STRUCT(method64_list_t,location)
    [self createObjC2Method64ListNode:childNode
                              caption:caption
                             location:location
                              methods:method64_list_t];
  }
  
  // Optional Instance Methods
  if (protocol64_t->optionalInstanceMethods && (childNode = [self sectionNodeContainsRVA64:protocol64_t->optionalInstanceMethods]))
  {
    uint32_t location = [self RVA64ToFileOffset:protocol64_t->optionalInstanceMethods];
    NSString * caption = [self findSymbolAtRVA64:protocol64_t->optionalInstanceMethods];
    MATCH_STRUCT(method64_list_t,location)
    [self createObjC2Method64ListNode:childNode
                              caption:caption
                             location:location
                              methods:method64_list_t];
  }
  
  // Optional Class Methods
  if (protocol64_t->optionalClassMethods && (childNode = [self sectionNodeContainsRVA64:protocol64_t->optionalClassMethods]))
  {
    uint32_t location = [self RVA64ToFileOffset:protocol64_t->optionalClassMethods];
    NSString * caption = [self findSymbolAtRVA64:protocol64_t->optionalClassMethods];
    MATCH_STRUCT(method64_list_t,location)
    [self createObjC2Method64ListNode:childNode
                              caption:caption
                             location:location
                              methods:method64_list_t];
  }
  
  // Instance Properties
  if (protocol64_t->instanceProperties && (childNode = [self sectionNodeContainsRVA64:protocol64_t->instanceProperties]))
  {
    uint32_t location = [self RVA64ToFileOffset:protocol64_t->instanceProperties];
    NSString * caption = [self findSymbolAtRVA64:protocol64_t->instanceProperties];
    MATCH_STRUCT(objc_property64_list,location)
    [self createObjC2Property64ListNode:childNode
                                caption:caption
                               location:location
                             properties:objc_property64_list];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2ProtocolListNode:(MVNode *)parent
                                caption:(NSString *)caption
                               location:(uint32_t)location
                              protocols:(struct protocol_list_t const *)protocol_list_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Protocol List: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct protocol_list_t) + protocol_list_t->count*sizeof(uint32_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Count"
                         :[NSString stringWithFormat:@"%u",protocol_list_t->count]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],
                              MVUnderlineAttributeName,@"YES",nil];
  
  for (uint32_t nprot = 0; nprot < protocol_list_t->count; ++nprot)
  {
    uint32_t protocolAddr = [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :[NSString stringWithFormat:@"list[%u]",nprot]
                           :[self findSymbolAtRVA:protocolAddr]];
    
    MVNode * childNode = [self sectionNodeContainsRVA:protocolAddr];
    if (childNode)
    {
      uint32_t location = [self RVAToFileOffset:protocolAddr];
      NSString * caption = [self findSymbolAtRVA:protocolAddr];
      MATCH_STRUCT(protocol_t,location)
      [self createObjC2ProtocolNode:childNode
                            caption:caption
                           location:location
                           protocol:protocol_t];
    }
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2Protocol64ListNode:(MVNode *)parent
                                  caption:(NSString *)caption
                                 location:(uint32_t)location
                                protocols:(struct protocol64_list_t const *)protocol64_list_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Protocol64 List: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct protocol64_list_t) + protocol64_list_t->count*sizeof(uint64_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Count"
                         :[NSString stringWithFormat:@"%qu",protocol64_list_t->count]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],
                              MVUnderlineAttributeName,@"YES",nil];
  
  for (uint64_t nprot = 0; nprot < protocol64_list_t->count; ++nprot)
  {
    uint64_t protocolAddr = [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :[NSString stringWithFormat:@"list[%qu]",nprot]
                           :[self findSymbolAtRVA64:protocolAddr]];
    
    MVNode * childNode = [self sectionNodeContainsRVA64:protocolAddr];
    if (childNode)
    {
      uint32_t location = [self RVA64ToFileOffset:protocolAddr];
      NSString * caption = [self findSymbolAtRVA64:protocolAddr];
      MATCH_STRUCT(protocol64_t,location)
      [self createObjC2Protocol64Node:childNode
                              caption:caption
                             location:location
                             protocol:protocol64_t];
    }
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2VariableListNode:(MVNode *)parent
                                caption:(NSString *)caption
                               location:(uint32_t)location
                              variables:(struct ivar_list_t const *)ivar_list_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Variable List: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct ivar_list_t) + ivar_list_t->count*sizeof(struct ivar_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Entry Size"
                         :[NSString stringWithFormat:@"%u",ivar_list_t->entsize]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],nil];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Count"
                         :[NSString stringWithFormat:@"%u",ivar_list_t->count]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],
                              MVUnderlineAttributeName,@"YES",nil];
  
  for (uint32_t nvar = 0; nvar < ivar_list_t->count; ++nvar)
  {
    MATCH_STRUCT(ivar_t,NSMaxRange(range))
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;

    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Offset"
                           :[self findSymbolAtRVA:ivar_t->offset]];

    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Name"
                           :(symbolName = [self findSymbolAtRVA:ivar_t->name])];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Type"
                           :[self findSymbolAtRVA:ivar_t->type]];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Alignment"
                           :[NSString stringWithFormat:@"%u",ivar_t->alignment]];

    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Size"
                           :[NSString stringWithFormat:@"%u",ivar_t->size]];
    
    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
  }

  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2Variable64ListNode:(MVNode *)parent
                                  caption:(NSString *)caption
                                 location:(uint32_t)location
                                variables:(struct ivar64_list_t const *)ivar64_list_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Variable64 List: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct ivar64_list_t) + ivar64_list_t->count*sizeof(struct ivar64_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Entry Size"
                         :[NSString stringWithFormat:@"%u",ivar64_list_t->entsize]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],nil];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Count"
                         :[NSString stringWithFormat:@"%u",ivar64_list_t->count]];
  
  [node.details setAttributes:MVCellColorAttributeName,[NSColor greenColor],
                              MVUnderlineAttributeName,@"YES",nil];
  
  for (uint32_t nvar = 0; nvar < ivar64_list_t->count; ++nvar)
  {
    MATCH_STRUCT(ivar64_t,NSMaxRange(range))
    
    // accumulate search info
    NSUInteger bookmark = node.details.rowCount;
    NSString * symbolName = nil;
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Offset"
                           :[self findSymbolAtRVA64:ivar64_t->offset]];
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Name"
                           :(symbolName = [self findSymbolAtRVA64:ivar64_t->name])];
    
    [dataController read_uint64:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Type"
                           :[self findSymbolAtRVA64:ivar64_t->type]];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Alignment"
                           :[NSString stringWithFormat:@"%u",ivar64_t->alignment]];
    
    [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Size"
                           :[NSString stringWithFormat:@"%u",ivar64_t->size]];
    
    [node.details setAttributesFromRowIndex:bookmark:MVMetaDataAttributeName,symbolName,nil];
    [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2ClassRONode:(MVNode *)parent
                           caption:(NSString *)caption
                          location:(uint32_t)location
                           classRO:(struct class_ro_t const *)class_ro_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }

  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Class Info: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct class_ro_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Flags"
                         :@""];
  
  if (class_ro_t->flags & RO_META) [node.details appendRow:@"":@"":@"0x1":@"RO_META"];
  if (class_ro_t->flags & RO_ROOT) [node.details appendRow:@"":@"":@"0x2":@"RO_ROOT"];
  if (class_ro_t->flags & RO_HAS_CXX_STRUCTORS) [node.details appendRow:@"":@"":@"0x4":@"RO_HAS_CXX_STRUCTORS"];
  if (class_ro_t->flags & RO_HAS_LOAD_METHOD) [node.details appendRow:@"":@"":@"0x8":@"RO_HAS_LOAD_METHOD"];
  if (class_ro_t->flags & RO_HIDDEN) [node.details appendRow:@"":@"":@"0x10":@"RO_HIDDEN"];
  if (class_ro_t->flags & RO_EXCEPTION) [node.details appendRow:@"":@"":@"0x20":@"RO_EXCEPTION"];
  if (class_ro_t->flags & RO_HAS_SWIFT_INITIALIZER) [node.details appendRow:@"":@"":@"0x40":@"RO_HAS_SWIFT_INITIALIZER"];
  if (class_ro_t->flags & RO_IS_ARC) [node.details appendRow:@"":@"":@"0x80":@"RO_IS_ARC"];
  if (class_ro_t->flags & RO_HAS_CXX_DTOR_ONLY) [node.details appendRow:@"":@"":@"0x100":@"RO_HAS_CXX_DTOR_ONLY"];
  if (class_ro_t->flags & RO_HAS_WEAK_WITHOUT_ARC) [node.details appendRow:@"":@"":@"0x200":@"RO_HAS_WEAK_WITHOUT_ARC"];
  if (class_ro_t->flags & RO_FORBIDS_ASSOCIATED_OBJECTS) [node.details appendRow:@"":@"":@"0x400":@"RO_FORBIDS_ASSOCIATED_OBJECTS"];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Start"
                         :[NSString stringWithFormat:@"%u", class_ro_t->instanceStart]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Size"
                         :[NSString stringWithFormat:@"%u", class_ro_t->instanceSize]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Var Layout"
                         :[self findSymbolAtRVA:class_ro_t->ivarLayout]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Name"
                         :[self findSymbolAtRVA:class_ro_t->name]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Base Methods"
                         :[self findSymbolAtRVA:class_ro_t->baseMethods]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Base Protocols"
                         :[self findSymbolAtRVA:class_ro_t->baseProtocols]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Variables"
                         :[self findSymbolAtRVA:class_ro_t->ivars]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Weak Instance Var Layout"
                         :[self findSymbolAtRVA:class_ro_t->weakIvarLayout]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Base Properties"
                         :[self findSymbolAtRVA:class_ro_t->baseProperties]];
   
  MVNode * childNode = nil;
  
  // Base Methods
  if (class_ro_t->baseMethods && (childNode = [self sectionNodeContainsRVA:class_ro_t->baseMethods]))
  {
    uint32_t location = [self RVAToFileOffset:class_ro_t->baseMethods];
    NSString * caption = [self findSymbolAtRVA:class_ro_t->baseMethods];
    MATCH_STRUCT(method_list_t,location)
    [self createObjC2MethodListNode:childNode
                            caption:caption
                           location:location
                            methods:method_list_t];
  }

  // Base Protocols
  if (class_ro_t->baseProtocols && (childNode = [self sectionNodeContainsRVA:class_ro_t->baseProtocols]))
  {
    uint32_t location = [self RVAToFileOffset:class_ro_t->baseProtocols];
    NSString * caption = [self findSymbolAtRVA:class_ro_t->baseProtocols];
    MATCH_STRUCT(protocol_list_t,location)
    [self createObjC2ProtocolListNode:childNode
                              caption:caption
                             location:location
                            protocols:protocol_list_t];
  }

  // Instance Variables
  if (class_ro_t->ivars && (childNode = [self sectionNodeContainsRVA:class_ro_t->ivars]))
  {
    uint32_t location = [self RVAToFileOffset:class_ro_t->ivars];
    NSString * caption = [self findSymbolAtRVA:class_ro_t->ivars];
    MATCH_STRUCT(ivar_list_t,location)
    [self createObjC2VariableListNode:childNode
                              caption:caption
                             location:location
                            variables:ivar_list_t];
  }

  // Base Properties
  if (class_ro_t->baseProperties && (childNode = [self sectionNodeContainsRVA:class_ro_t->baseProperties]))
  {
    uint32_t location = [self RVAToFileOffset:class_ro_t->baseProperties];
    NSString * caption = [self findSymbolAtRVA:class_ro_t->baseProperties];
    MATCH_STRUCT(objc_property_list,location)
    [self createObjC2PropertyListNode:childNode
                              caption:caption
                             location:location
                           properties:objc_property_list];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2Class64RONode:(MVNode *)parent
                             caption:(NSString *)caption
                            location:(uint32_t)location
                             classRO:(struct class64_ro_t const *)class64_ro_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }

  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Class64 Info: " stringByAppendingString:caption]
                               location:location 
                                 length:sizeof(struct class64_ro_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Flags"
                         :@""];
  
  if (class64_ro_t->flags & RO_META) [node.details appendRow:@"":@"":@"0x1":@"RO_META"];
  if (class64_ro_t->flags & RO_ROOT) [node.details appendRow:@"":@"":@"0x2":@"RO_ROOT"];
  if (class64_ro_t->flags & RO_HAS_CXX_STRUCTORS) [node.details appendRow:@"":@"":@"0x4":@"RO_HAS_CXX_STRUCTORS"];
  if (class64_ro_t->flags & RO_HAS_LOAD_METHOD) [node.details appendRow:@"":@"":@"0x8":@"RO_HAS_LOAD_METHOD"];
  if (class64_ro_t->flags & RO_HIDDEN) [node.details appendRow:@"":@"":@"0x10":@"RO_HIDDEN"];
  if (class64_ro_t->flags & RO_EXCEPTION) [node.details appendRow:@"":@"":@"0x20":@"RO_EXCEPTION"];
  if (class64_ro_t->flags & RO_HAS_SWIFT_INITIALIZER) [node.details appendRow:@"":@"":@"0x40":@"RO_HAS_SWIFT_INITIALIZER"];
  if (class64_ro_t->flags & RO_IS_ARC) [node.details appendRow:@"":@"":@"0x80":@"RO_IS_ARC"];
  if (class64_ro_t->flags & RO_HAS_CXX_DTOR_ONLY) [node.details appendRow:@"":@"":@"0x100":@"RO_HAS_CXX_DTOR_ONLY"];
  if (class64_ro_t->flags & RO_HAS_WEAK_WITHOUT_ARC) [node.details appendRow:@"":@"":@"0x200":@"RO_HAS_WEAK_WITHOUT_ARC"];
  if (class64_ro_t->flags & RO_FORBIDS_ASSOCIATED_OBJECTS) [node.details appendRow:@"":@"":@"0x400":@"RO_FORBIDS_ASSOCIATED_OBJECTS"];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Start"
                         :[NSString stringWithFormat:@"%u", class64_ro_t->instanceStart]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Size"
                         :[NSString stringWithFormat:@"%u", class64_ro_t->instanceSize]];
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Reserved"
                         :[NSString stringWithFormat:@"%u", class64_ro_t->reserved]];

  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Var Layout"
                         :[self findSymbolAtRVA64:class64_ro_t->ivarLayout]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Name"
                         :[self findSymbolAtRVA64:class64_ro_t->name]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Base Methods"
                         :[self findSymbolAtRVA64:class64_ro_t->baseMethods]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Base Protocols"
                         :[self findSymbolAtRVA64:class64_ro_t->baseProtocols]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Variables"
                         :[self findSymbolAtRVA64:class64_ro_t->ivars]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Weak Instance Var Layout"
                         :[self findSymbolAtRVA64:class64_ro_t->weakIvarLayout]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Base Properties"
                         :[self findSymbolAtRVA64:class64_ro_t->baseProperties]];
  
  MVNode * childNode = nil;
  
  // Base Methods
  if (class64_ro_t->baseMethods && (childNode = [self sectionNodeContainsRVA64:class64_ro_t->baseMethods]))
  {
    uint32_t location = [self RVA64ToFileOffset:class64_ro_t->baseMethods];
    NSString * caption = [self findSymbolAtRVA64:class64_ro_t->baseMethods];
    MATCH_STRUCT(method64_list_t,location)
    [self createObjC2Method64ListNode:childNode
                              caption:caption
                             location:location
                              methods:method64_list_t];
  }
  
  // Base Protocols
  if (class64_ro_t->baseProtocols && (childNode = [self sectionNodeContainsRVA64:class64_ro_t->baseProtocols]))
  {
    uint32_t location = [self RVA64ToFileOffset:class64_ro_t->baseProtocols];
    NSString * caption = [self findSymbolAtRVA64:class64_ro_t->baseProtocols];
    MATCH_STRUCT(protocol64_list_t,location)
    [self createObjC2Protocol64ListNode:childNode
                                caption:caption
                               location:location
                              protocols:protocol64_list_t];
  }
  
  // Instance Variables
  if (class64_ro_t->ivars && (childNode = [self sectionNodeContainsRVA64:class64_ro_t->ivars]))
  {
    uint32_t location = [self RVA64ToFileOffset:class64_ro_t->ivars];
    NSString * caption = [self findSymbolAtRVA64:class64_ro_t->ivars];
    MATCH_STRUCT(ivar64_list_t,location)
    [self createObjC2Variable64ListNode:childNode
                                caption:caption
                               location:location
                              variables:ivar64_list_t];
  }
  
  // Base Properties
  if (class64_ro_t->baseProperties && (childNode = [self sectionNodeContainsRVA64:class64_ro_t->baseProperties]))
  {
    uint32_t location = [self RVA64ToFileOffset:class64_ro_t->baseProperties];
    NSString * caption = [self findSymbolAtRVA64:class64_ro_t->baseProperties];
    MATCH_STRUCT(objc_property64_list,location)
    [self createObjC2Property64ListNode:childNode
                                caption:caption
                               location:location
                             properties:objc_property64_list];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2ClassNode:(MVNode *)parent
                         caption:(NSString *)caption
                        location:(uint32_t)location
                           class:(struct class_t const *)class_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  MVNode * childNode = nil;

  node = [parent insertChildWithDetails:[@"ObjC2 Class: " stringByAppendingString:caption]
                               location:location
                                 length:sizeof(struct class_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"ISA"
                         :[self findSymbolAtRVA:class_t->isa]];

    // Meta Class
    if (class_t->isa && (childNode = [self sectionNodeContainsRVA64:class_t->isa])) {
      uint32_t location = [self RVA64ToFileOffset:class_t->isa];
      NSString * caption = [self findSymbolAtRVA64:class_t->isa];
        MATCH_STRUCT(class_t,location)
        [self createObjC2ClassNode:childNode
                           caption:caption
                          location:location
                             class:class_t];
    }

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Super Class"
                         :[self findSymbolAtRVA:class_t->superclass]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Cache"
                         :[self findSymbolAtRVA:class_t->cache]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"VTable"
                         :[self findSymbolAtRVA:class_t->vtable]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Data"
                         :[self findSymbolAtRVA:class_t->data]];

  // readonly data
  if (class_t->data && (childNode = [self sectionNodeContainsRVA:class_t->data]))
  {
    uint32_t location = [self RVAToFileOffset:class_t->data];
    NSString * caption = [self findSymbolAtRVA:class_t->data];
    MATCH_STRUCT(class_ro_t,location)
    [self createObjC2ClassRONode:childNode
                         caption:caption
                        location:location
                         classRO:class_ro_t];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2Class64Node:(MVNode *)parent
                           caption:(NSString *)caption
                          location:(uint32_t)location
                             class:(struct class64_t const *)class64_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  MVNode * childNode = nil;

  node = [parent insertChildWithDetails:[@"ObjC2 Class64: " stringByAppendingString:caption]
                               location:location
                                 length:sizeof(struct class64_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"ISA"
                         :[self findSymbolAtRVA64:class64_t->isa]];

    // Meta Class
    if (class64_t->isa && (childNode = [self sectionNodeContainsRVA64:class64_t->isa])) {
      uint32_t location = [self RVA64ToFileOffset:class64_t->isa];
        NSString * caption = [self findSymbolAtRVA64:class64_t->isa];
        MATCH_STRUCT(class64_t,location)
        [self createObjC2Class64Node:childNode
                             caption:caption
                            location:location
                               class:class64_t];
    }
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Super Class"
                         :[self findSymbolAtRVA64:class64_t->superclass]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Cache"
                         :[self findSymbolAtRVA64:class64_t->cache]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"VTable"
                         :[self findSymbolAtRVA64:class64_t->vtable]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Data"
                         :[self findSymbolAtRVA64:class64_t->data & ~0x1]];

  // readonly data
  if (class64_t->data && (childNode = [self sectionNodeContainsRVA64:class64_t->data]))
  {
    uint32_t location = [self RVA64ToFileOffset:class64_t->data];
      if ((location & 0x1) == 0) {
          NSString * caption = [self findSymbolAtRVA64:class64_t->data];
          MATCH_STRUCT(class64_ro_t,location)
          [self createObjC2Class64RONode:childNode
                                 caption:caption
                                location:location
                                 classRO:class64_ro_t];
      } else {
          NSString * caption = [self findSymbolAtRVA64:class64_t->data & ~0x1];
          MATCH_STRUCT(class64_ro_t,location & ~0x1)
          [self createObjC2Class64RONode:childNode
                                 caption:caption
                                location:location & ~0x1
                                 classRO:class64_ro_t];
      }
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createObjC2CategoryNode:(MVNode *)parent
                            caption:(NSString *)caption
                           location:(uint32_t)location
                           category:(struct category_t const *)category_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Category: " stringByAppendingString:caption]
                               location:location
                                 length:sizeof(struct category_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Name"
                         :[self findSymbolAtRVA:category_t->name]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Class"
                         :[self findSymbolAtRVA:category_t->cls]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Methods"
                         :[self findSymbolAtRVA:category_t->instanceMethods]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Class Methods"
                         :[self findSymbolAtRVA:category_t->classMethods]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Protocols"
                         :[self findSymbolAtRVA:category_t->protocols]];

  [dataController read_uint32:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Properties"
                         :[self findSymbolAtRVA:category_t->instanceProperties]];

  MVNode * childNode = nil;
  
  // CLS
  if (category_t->cls && (childNode = [self sectionNodeContainsRVA:category_t->cls]))
  {
    uint32_t location = [self RVAToFileOffset:category_t->cls]; 
    NSString * caption = [self findSymbolAtRVA:category_t->cls];
    MATCH_STRUCT(class_t,location)
    [self createObjC2ClassNode:childNode
                       caption:caption
                      location:location
                         class:class_t];
  }
  
  // Instance Methods
  if (category_t->instanceMethods && (childNode = [self sectionNodeContainsRVA:category_t->instanceMethods]))
  {
    uint32_t location = [self RVAToFileOffset:category_t->instanceMethods]; 
    NSString * caption = [self findSymbolAtRVA:category_t->instanceMethods];
    MATCH_STRUCT(method_list_t,location)
    [self createObjC2MethodListNode:childNode
                            caption:caption
                           location:location
                            methods:method_list_t];
  }

  // Class Methods
  if (category_t->classMethods && (childNode = [self sectionNodeContainsRVA:category_t->classMethods]))
  {
    uint32_t location = [self RVAToFileOffset:category_t->classMethods]; 
    NSString * caption = [self findSymbolAtRVA:category_t->classMethods];
    MATCH_STRUCT(method_list_t,location)
    [self createObjC2MethodListNode:childNode
                            caption:caption
                           location:location
                            methods:method_list_t];
  }
  
  // Protocols
  if (category_t->protocols && (childNode = [self sectionNodeContainsRVA:category_t->protocols]))
  {
    uint32_t location = [self RVAToFileOffset:category_t->protocols]; 
    NSString * caption = [self findSymbolAtRVA:category_t->protocols];
    MATCH_STRUCT(protocol_list_t,location)
    [self createObjC2ProtocolListNode:childNode
                              caption:caption
                             location:location
                            protocols:protocol_list_t];
  }
  
  // Instance Properties
  if (category_t->instanceProperties && (childNode = [self sectionNodeContainsRVA:category_t->instanceProperties]))
  {
    uint32_t location = [self RVAToFileOffset:category_t->instanceProperties]; 
    NSString * caption = [self findSymbolAtRVA:category_t->instanceProperties];
    MATCH_STRUCT(objc_property_list,location)
    [self createObjC2PropertyListNode:childNode
                              caption:caption
                             location:location
                           properties:objc_property_list];
  }
  
  return node;
}
  
//------------------------------------------------------------------------------
- (MVNode *)createObjC2Category64Node:(MVNode *)parent
                              caption:(NSString *)caption
                             location:(uint32_t)location
                             category:(struct category64_t const *)category64_t
{  
  // check for parent
  if (parent == nil)
  {
    return nil;
  }
  
  // check for duplicates
  MVNode * node = [self entryInSectionNode:parent atLocation:location];
  if (node != nil)
  {
    return node;
  }
  
  MVNodeSaver nodeSaver;
  node = [parent insertChildWithDetails:[@"ObjC2 Category64: " stringByAppendingString:caption]
                               location:location
                                 length:sizeof(struct category64_t)
                                  saver:nodeSaver];
  
  NSRange range = NSMakeRange(location,0);
  NSString * lastReadHex;
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Name"
                         :[self findSymbolAtRVA64:category64_t->name]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"CLS"
                         :[self findSymbolAtRVA64:category64_t->cls]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Methods"
                         :[self findSymbolAtRVA64:category64_t->instanceMethods]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Class Methods"
                         :[self findSymbolAtRVA64:category64_t->classMethods]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Protocols"
                         :[self findSymbolAtRVA64:category64_t->protocols]];
  
  [dataController read_uint64:range lastReadHex:&lastReadHex];
  [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                         :lastReadHex
                         :@"Instance Properties"
                         :[self findSymbolAtRVA64:category64_t->instanceProperties]];
  
  MVNode * childNode = nil;
  
  // CLS
  if (category64_t->cls && (childNode = [self sectionNodeContainsRVA64:category64_t->cls]))
  {
    uint32_t location = [self RVA64ToFileOffset:category64_t->cls];
    NSString * caption = [self findSymbolAtRVA64:category64_t->cls];
    MATCH_STRUCT(class64_t,location)
    [self createObjC2Class64Node:childNode
                         caption:caption
                        location:location
                           class:class64_t];
  }
  
  // Instance Methods
  if (category64_t->instanceMethods && (childNode = [self sectionNodeContainsRVA64:category64_t->instanceMethods]))
  {
    uint32_t location = [self RVA64ToFileOffset:category64_t->instanceMethods];
    NSString * caption = [self findSymbolAtRVA64:category64_t->instanceMethods];
    MATCH_STRUCT(method64_list_t,location)
    [self createObjC2Method64ListNode:childNode
                              caption:caption
                             location:location
                              methods:method64_list_t];
  }
  
  // Class Methods
  if (category64_t->classMethods && (childNode = [self sectionNodeContainsRVA64:category64_t->classMethods]))
  {
    uint32_t location = [self RVA64ToFileOffset:category64_t->classMethods];
    NSString * caption = [self findSymbolAtRVA64:category64_t->classMethods];
    MATCH_STRUCT(method64_list_t,location)
    [self createObjC2Method64ListNode:childNode
                              caption:caption
                             location:location
                              methods:method64_list_t];
  }
  
  // Protocols
  if (category64_t->protocols && (childNode = [self sectionNodeContainsRVA64:category64_t->protocols]))
  {
    uint32_t location = [self RVA64ToFileOffset:category64_t->protocols];
    NSString * caption = [self findSymbolAtRVA64:category64_t->protocols];
    MATCH_STRUCT(protocol64_list_t,location)
    [self createObjC2Protocol64ListNode:childNode
                                caption:caption
                               location:location
                              protocols:protocol64_list_t];
  }
  
  // Instance Properties
  if (category64_t->instanceProperties && (childNode = [self sectionNodeContainsRVA64:category64_t->instanceProperties]))
  {
    uint32_t location = [self RVA64ToFileOffset:category64_t->instanceProperties];
    NSString * caption = [self findSymbolAtRVA64:category64_t->instanceProperties];
    MATCH_STRUCT(objc_property64_list,location)
    [self createObjC2Property64ListNode:childNode
                                caption:caption
                               location:location
                             properties:objc_property64_list];
  }
  
  return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createSwiftType64Node:(MVNode *)parent
                              caption:(NSString *)caption
                             location:(uint32_t)location
                             swiftType:(struct swift_type const *)swiftType
{
        // check for parent
    if (parent == nil)
    {
        return nil;
    }

        // check for duplicates
    MVNode * node = [self entryInSectionNode:parent atLocation:location];
    if (node != nil)
    {
        return node;
    }

    uint32_t length = 0;
    {
        uint8_t kind = swiftType->flags & 0x1F;
        if (kind == SWIFT_CONTEXT_DESCRIPTOR_KIND_CLASS) {
            length = sizeof(struct swift_type_class);
        } else if (kind == SWIFT_CONTEXT_DESCRIPTOR_KIND_STRUCT) {
            length = sizeof(struct swift_type_struct);
        } else {
            length = sizeof(struct swift_type);
        }
    }

    MVNodeSaver nodeSaver;
    node = [parent insertChildWithDetails:[@"Swift Type: " stringByAppendingString:caption]
                                 location:location
                                   length:length
                                    saver:nodeSaver];

    NSRange range = NSMakeRange(location,0);
    NSString * lastReadHex;

    uint32_t flags = [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Flags"
                           :lastReadHex];

    uint8_t kind = flags & 0x1F;
    NSString *kindString = nil;
    switch (kind) {
        case SWIFT_CONTEXT_DESCRIPTOR_KIND_MODULE: {
            kindString = @"Module";
        } break;
        case SWIFT_CONTEXT_DESCRIPTOR_KIND_EXTENSION: {
            kindString = @"Extension";
        } break;
        case SWIFT_CONTEXT_DESCRIPTOR_KIND_ANONYMOUS: {
            kindString = @"Anonymous";
        } break;
        case SWIFT_CONTEXT_DESCRIPTOR_KIND_PROTOCOL: {
            kindString = @"Protocol";
        } break;
        case SWIFT_CONTEXT_DESCRIPTOR_KIND_OPAQUE_TYPE: {
            kindString = @"OpaqueType";
        } break;
        case SWIFT_CONTEXT_DESCRIPTOR_KIND_CLASS: {
            kindString = @"Class";
        } break;
        case SWIFT_CONTEXT_DESCRIPTOR_KIND_STRUCT: {
            kindString = @"Struct";
        } break;
        case SWIFT_CONTEXT_DESCRIPTOR_KIND_ENUM: {
            kindString = @"Enum";
        } break;
        case SWIFT_CONTEXT_DESCRIPTOR_KIND_ANY: {
            kindString = @"Any";
        } break;
        default: {
            kindString = @"Unknown";
        } break;
    }
    [node.details appendRow:@"":@"":@"0x1F":[NSString stringWithFormat:@"KIND(%.2lX)(%@)", kind, kindString]];

    if (flags & 0x80) [node.details appendRow:@"":@"":@"0x80":@"IS_GENERIC"];
    if (flags & 0x40) [node.details appendRow:@"":@"":@"0x40":@"IS_UNIQUE"];
    if ((flags >> 8) & 0xFF) [node.details appendRow:@"":@"":@"0xFF00":[NSString stringWithFormat:@"VERSION(%.2lX)", (flags >> 8) & 0xFF]];
    uint16_t descriptorFlags = (flags >> 16) & 0xFFFF;
    if (descriptorFlags) [node.details appendRow:@"":@"":@"0xFFFF0000":[NSString stringWithFormat:@"KIND_SPECIFIC_FLAGS(%.4lX)", descriptorFlags]];

    uint8_t metadataInitializationFlag = descriptorFlags & 0x3;
    if (metadataInitializationFlag == NoMetadataInitialization) {
        [node.details appendRow:@"":@"":@"0x00030000":@"No Metadata Initialization"];
    } else if (metadataInitializationFlag == SingletonMetadataInitialization) {
        [node.details appendRow:@"":@"":@"0x00030000":@"Singleton Metadata Initialization"];
    } else if (metadataInitializationFlag == ForeignMetadataInitialization) {
        [node.details appendRow:@"":@"":@"0x00030000":@"Foreign Metadata Initialization"];
    }
    if (descriptorFlags & (1 << HasImportInfo))
        [node.details appendRow:@"":@"":@"0x00100000":@"Has Import Info"];
    if (descriptorFlags & (1 << HasCanonicalMetadataPrespecializations))
        [node.details appendRow:@"":@"":@"0x00100000":@"Has Canonical Metadata Prespecializations"];
    if (descriptorFlags & (1 << HasLayoutString))
        [node.details appendRow:@"":@"":@"0x00100000":@"Has Layout String"];
    if (descriptorFlags & (1 << Class_IsActor))
        [node.details appendRow:@"":@"":@"0x00800000":@"Class Is Actor"];
    if (descriptorFlags & (1 << Class_IsDefaultActor))
        [node.details appendRow:@"":@"":@"0x01000000":@"Class Is Default Actor"];
    if (descriptorFlags & (1 << Class_AreImmediateMembersNegative))
        [node.details appendRow:@"":@"":@"0x10000000":@"Class Are Immediate Members Negative"];
    BOOL hasResilientSuperclass = descriptorFlags & (1 << Class_HasResilientSuperclass);
    if (hasResilientSuperclass)
        [node.details appendRow:@"":@"":@"0x20000000":@"Class Has Resilient Superclass"];
    if (descriptorFlags & (1 << Class_HasOverrideTable))
        [node.details appendRow:@"":@"":@"0x40000000":@"Class Has Override Table"];
    BOOL hasVTable = descriptorFlags & (1 << Class_HasVTable);
    if (hasVTable)
        [node.details appendRow:@"":@"":@"0x80000000":@"Class Has VTable"];

    uint32_t parentOffsetValue = 0;
    uint32_t parentOffset = [dataController read_uint32_offset:range lastReadHex:&lastReadHex offset:&parentOffsetValue];
    uint64_t parentAddress = [self fileOffsetToRVA64:parentOffset];

    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Parent"
                           :parentOffsetValue ? [self findSymbolAtRVA64:parentAddress] : @"00000000"];

    MVNode * childNode = nil;
    if (parentOffsetValue && parentAddress && (childNode = [self sectionNodeContainsRVA64:parentAddress]))
    {
        uint32_t location = [self RVA64ToFileOffset:parentAddress];
        NSString * caption = [self findSymbolAtRVA64:parentAddress];
        MATCH_STRUCT(swift_type,location)
        [self createSwiftType64Node:childNode
                            caption:caption
                           location:location
                          swiftType:swift_type];
    }

    if (kind == SWIFT_CONTEXT_DESCRIPTOR_KIND_MODULE ||
        kind == SWIFT_CONTEXT_DESCRIPTOR_KIND_CLASS ||
        kind == SWIFT_CONTEXT_DESCRIPTOR_KIND_STRUCT ||
        kind == SWIFT_CONTEXT_DESCRIPTOR_KIND_ENUM) {
        uint32_t nameOffset = [dataController read_uint32_offset:range lastReadHex:&lastReadHex];
        uint64_t nameAddress = [self fileOffsetToRVA64:nameOffset];
        const char *name = (const char *)[self imageAt:nameOffset];
        [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                               :lastReadHex
                               :@"Name"
                               :[NSString stringWithFormat:@"0x%.8lX(%s)", nameAddress, name]];

        if (kind == SWIFT_CONTEXT_DESCRIPTOR_KIND_CLASS) {
            uint32_t functionOffset = [dataController read_uint32_offset:range lastReadHex:&lastReadHex];
            uint64_t functionAddress = [self fileOffsetToRVA64:functionOffset];
            [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                   :lastReadHex
                                   :@"Access Function"
                                   :[self findSymbolAtRVA64:functionAddress]];

            uint32_t fdOffset = [dataController read_uint32_offset:range lastReadHex:&lastReadHex];
            uint64_t fdAddress = [self fileOffsetToRVA64:fdOffset];
            [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                   :lastReadHex
                                   :@"Field Descriptor"
                                   :[self findSymbolAtRVA64:fdAddress]];

            if (fdAddress && (childNode = [self sectionNodeContainsRVA64:fdAddress]))
            {
                uint32_t location = [self RVA64ToFileOffset:fdAddress];
                NSString * caption = [self findSymbolAtRVA64:fdAddress];
                MATCH_STRUCT(swift_field_descriptor,location)
                [self createSwiftFieldDescriptorNode:childNode
                                             caption:caption
                                            location:location
                                     filedDescriptor:swift_field_descriptor];
            }

            if (kind == SWIFT_CONTEXT_DESCRIPTOR_KIND_CLASS) {
                uint32_t superclassOffsetValue = 0;
                uint32_t superclassOffset = [dataController read_uint32_offset:range lastReadHex:&lastReadHex offset:&superclassOffsetValue];
                uint64_t superclassAddress = [self fileOffsetToRVA64:superclassOffset];
                NSString *superclassDescription = @"00000000";
                if (superclassOffsetValue) {
                    const char *superclassname = (const char *)[self imageAt:superclassOffset];
                    superclassDescription = [NSString stringWithFormat:@"0x%.8llX(%s)", superclassAddress, superclassname];
                }
                [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                       :lastReadHex
                                       :@"Super Class"
                                       :superclassDescription];

                uint32_t negativeSize = [dataController read_uint32:range lastReadHex:&lastReadHex];
                [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                       :lastReadHex
                                       :@"Negative Size"
                                       :[NSString stringWithFormat:@"%u", negativeSize]];

                uint32_t positiveSize = [dataController read_uint32:range lastReadHex:&lastReadHex];
                [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                       :lastReadHex
                                       :@"Positive Size"
                                       :[NSString stringWithFormat:@"%u", positiveSize]];

                uint32_t numberOfImmediateMembers = [dataController read_uint32:range lastReadHex:&lastReadHex];
                [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                       :lastReadHex
                                       :@"Number of Immediate Members"
                                       :[NSString stringWithFormat:@"%u", numberOfImmediateMembers]];

                uint32_t numberOfFields = [dataController read_uint32:range lastReadHex:&lastReadHex];
                [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                       :lastReadHex
                                       :@"Number of Fields"
                                       :[NSString stringWithFormat:@"%u", numberOfFields]];

                uint32_t fieldOffsetVectorOffset = [dataController read_uint32:range lastReadHex:&lastReadHex];
                [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                       :lastReadHex
                                       :@"Field Offset Vector Offset"
                                       :[NSString stringWithFormat:@"%u", fieldOffsetVectorOffset]];
                if (hasResilientSuperclass) {
                    uint32_t resilientSuperclassOffsetValue = 0;
                    uint32_t resilientSuperclassOffset = [dataController read_uint32_offset:range lastReadHex:&lastReadHex offset:&resilientSuperclassOffsetValue];
                    uint64_t resilientSuperclassAddress = [self fileOffsetToRVA64:resilientSuperclassOffset];
                    NSString *resilientSuperclassDescription = @"00000000";
                    if (resilientSuperclassOffsetValue) {
                        const char *superclassname = (const char *)[self imageAt:resilientSuperclassOffset];
                        resilientSuperclassDescription = [NSString stringWithFormat:@"0x%.8llX(%s)", resilientSuperclassAddress, superclassname];
                    }
                    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                           :lastReadHex
                                           :@"Resilient Super Class"
                                           :resilientSuperclassDescription];
                }
                if (metadataInitializationFlag) {
                    [dataController read_bytes:range length:12 lastReadHex:&lastReadHex];
                    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                           :lastReadHex
                                           :@"Metadata Initialization"
                                           :@""];
                }

                if (hasVTable) {
                    uint32_t vTableHeaderOffset = [dataController read_uint32:range lastReadHex:&lastReadHex];
                    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                           :lastReadHex
                                           :@"vTableHeaderOffset"
                                           :[NSString stringWithFormat:@"%u", vTableHeaderOffset]];

                    uint32_t vTableHeaderSize = [dataController read_uint32:range lastReadHex:&lastReadHex];
                    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                           :lastReadHex
                                           :@"vTable Method Count"
                                           :[NSString stringWithFormat:@"%u", vTableHeaderSize]];

                    for (uint32_t i = 0; i < vTableHeaderSize; i++) {
                        [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];

                        uint32_t flags = [dataController read_uint32:range lastReadHex:&lastReadHex];
                        [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                               :lastReadHex
                                               :@"Flags"
                                               :[NSString stringWithFormat:@"%.8X", flags]];

                        if ((flags & SWIFT_VTABLE_DESCRIPTOR_MASK_KIND) == swift_method_kind_method) {
                            [node.details appendRow:@"":@"":@"0x0":@"Method"];
                        } else if ((flags & SWIFT_VTABLE_DESCRIPTOR_MASK_KIND) == swift_method_kind_init) {
                            [node.details appendRow:@"":@"":@"0x1":@"Init"];
                        } else if ((flags & SWIFT_VTABLE_DESCRIPTOR_MASK_KIND) == swift_method_kind_getter) {
                            [node.details appendRow:@"":@"":@"0x2":@"Getter"];
                        } else if ((flags & SWIFT_VTABLE_DESCRIPTOR_MASK_KIND) == swift_method_kind_setter) {
                            [node.details appendRow:@"":@"":@"0x3":@"Setter"];
                        } else if ((flags & SWIFT_VTABLE_DESCRIPTOR_MASK_KIND) == swift_method_kind_modifyCoroutine) {
                            [node.details appendRow:@"":@"":@"0x4":@"Modify Coroutine"];
                        } else if ((flags & SWIFT_VTABLE_DESCRIPTOR_MASK_KIND) == swift_method_kind_readCoroutine) {
                            [node.details appendRow:@"":@"":@"0x5":@"Read Coroutine"];
                        }

                        if ((flags & SWIFT_VTABLE_DESCRIPTOR_MASK_IS_INSTANCE)) {
                            [node.details appendRow:@"":@"":@"0x10":@"Instance"];
                        }
                        if ((flags & SWIFT_VTABLE_DESCRIPTOR_MASK_IS_DYNAMIC)) {
                            [node.details appendRow:@"":@"":@"0x20":@"Dynamic"];
                        }

                        uint32_t impValue = 0;
                        uint32_t impOffset = [dataController read_uint32_offset:range lastReadHex:&lastReadHex offset:&impValue];
                        NSString *symbolName = @"00000000";
                        if (impValue) {
                            uint64_t impAddress = [self fileOffsetToRVA64:impOffset];
                            symbolName = [self findSymbolAtRVA64:impAddress];
                        }
                        [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                                               :lastReadHex
                                               :@"Implementation"
                                               :symbolName];
                    }
                }
            }
        }
    }

    return node;
}

//------------------------------------------------------------------------------
- (MVNode *)createSwiftFieldDescriptorNode:(MVNode *)parent
                                   caption:(NSString *)caption
                                  location:(uint32_t)location
                           filedDescriptor:(struct swift_field_descriptor const *)filedDescriptor
{
        // check for parent
    if (parent == nil)
    {
        return nil;
    }

        // check for duplicates
    MVNode * node = [self entryInSectionNode:parent atLocation:location];
    if (node != nil)
    {
        return node;
    }

    MVNodeSaver nodeSaver;
    node = [parent insertChildWithDetails:[@"Swift Field Descriptor: " stringByAppendingString:caption]
                                 location:location
                                   length:sizeof(struct swift_field_descriptor) + sizeof(struct swift_field_record) * filedDescriptor->number_of_records
                                    saver:nodeSaver];

    NSRange range = NSMakeRange(location,0);
    NSString * lastReadHex;

    uint32_t typeNameOffset = [dataController read_uint32_offset:range lastReadHex:&lastReadHex];
    uint64_t typeNameAddress = [self fileOffsetToRVA64:typeNameOffset];
    const char *typeName = (const char *)[self imageAt:typeNameOffset];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Type Name"
                           :[NSString stringWithFormat:@"0x%.8lX(%s)", typeNameAddress, typeName]];

    uint32_t superclassValue = 0;
    uint32_t superclassOffset = [dataController read_uint32_offset:range lastReadHex:&lastReadHex offset:&superclassValue];
    NSString *superclassDescription = @"00000000";
    if (superclassValue) {
        uint64_t superclassAddress = [self fileOffsetToRVA64:superclassOffset];
        const char *superclassName = (const char *)[self imageAt:superclassOffset];
        superclassDescription = [NSString stringWithFormat:@"0x%.8lX(%s)", superclassAddress, superclassName];
    }
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Super Class"
                           :superclassDescription];

    uint32_t kind = [dataController read_uint16:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Kind"
                           :[NSString stringWithFormat:@"%.4lX", kind]];

    uint32_t fieldRecordSize = [dataController read_uint16:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Record Size"
                           :[NSString stringWithFormat:@"%.4lX", fieldRecordSize]];

    uint32_t numberOfRecords = [dataController read_uint32:range lastReadHex:&lastReadHex];
    [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                           :lastReadHex
                           :@"Number of Records"
                           :[NSString stringWithFormat:@"%i", numberOfRecords]];

    for (uint32_t i = 0; i < numberOfRecords; i++) {
        [node.details setAttributes:MVUnderlineAttributeName,@"YES",nil];

        uint32_t flags = [dataController read_uint32:range lastReadHex:&lastReadHex];
        [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                               :lastReadHex
                               :@"Flags"
                               :[NSString stringWithFormat:@"%.8lX", flags]];

        uint32_t nameValue = 0;
        uint32_t nameOffset = [dataController read_uint32_offset:range lastReadHex:&lastReadHex offset:&nameValue];
        uint64_t nameAddress = [self fileOffsetToRVA64:nameOffset];
        const char *nameName = (const char *)[self imageAt:nameOffset];
        [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                               :lastReadHex
                               :@"Record Name"
                               :[NSString stringWithFormat:@"0x%.8lX(%s)", nameAddress, nameName]];

        uint32_t fieldNameValue = 0;
        uint32_t fieldNameOffset = [dataController read_uint32_offset:range lastReadHex:&lastReadHex offset:&fieldNameValue];
        uint64_t fieldNameAddress = [self fileOffsetToRVA64:fieldNameOffset];
        const char *fieldNameName = (const char *)[self imageAt:fieldNameOffset];
        [node.details appendRow:[NSString stringWithFormat:@"%.8lX", range.location]
                               :lastReadHex
                               :@"Record Field Name"
                               :[NSString stringWithFormat:@"0x%.8lX(%s)", fieldNameAddress, fieldNameName]];
    }

    return node;
}

//------------------------------------------------------------------------------
-(void)parseObjC2ClassPointers:(PointerVector const *)classes
          NonLazyClassPointers:(PointerVector const *)nlClasses
              CategoryPointers:(PointerVector const *)categories
       NonLazyCategoryPointers:(PointerVector const *)nlcategories
              ProtocolPointers:(PointerVector const *)protocols
{
  MVNode * node = nil;
  
  for (PointerVector::const_iterator iter = classes->begin(); iter != classes->end(); ++iter)
  {
    uint32_t const & rva = *iter;
    if (rva && (node = [self sectionNodeContainsRVA:rva]))
    {
      uint32_t location = [self RVAToFileOffset:rva]; 
      NSString * caption = [self findSymbolAtRVA:rva];
      MATCH_STRUCT(class_t,location)
      [self createObjC2ClassNode:node
                         caption:caption
                        location:location
                           class:class_t];
    }
  }

    for (PointerVector::const_iterator iter = nlClasses->begin(); iter != nlClasses->end(); ++iter)
    {
      uint32_t const & rva = *iter;
      if (rva && (node = [self sectionNodeContainsRVA:rva]))
      {
        uint32_t location = [self RVAToFileOffset:rva];
        NSString * caption = [self findSymbolAtRVA:rva];
        MATCH_STRUCT(class_t,location)
        [self createObjC2ClassNode:node
                           caption:caption
                          location:location
                             class:class_t];
      }
    }

  for (PointerVector::const_iterator iter = categories->begin(); iter != categories->end(); ++iter)
  {
    uint32_t const & rva = *iter;
    if (rva && (node = [self sectionNodeContainsRVA:rva]))
    {
      uint32_t location = [self RVAToFileOffset:rva]; 
      NSString * caption = [self findSymbolAtRVA:rva];
      MATCH_STRUCT(category_t,location)
      [self createObjC2CategoryNode:node
                            caption:caption
                           location:location
                           category:category_t];
    }
  }

    for (PointerVector::const_iterator iter = nlcategories->begin(); iter != nlcategories->end(); ++iter)
    {
      uint32_t const & rva = *iter;
      if (rva && (node = [self sectionNodeContainsRVA:rva]))
      {
        uint32_t location = [self RVAToFileOffset:rva];
        NSString * caption = [self findSymbolAtRVA:rva];
        MATCH_STRUCT(category_t,location)
        [self createObjC2CategoryNode:node
                              caption:caption
                             location:location
                             category:category_t];
      }
    }

  for (PointerVector::const_iterator iter = protocols->begin(); iter != protocols->end(); ++iter)
  {
    uint32_t const & rva = *iter;
    if (rva && (node = [self sectionNodeContainsRVA:rva]))
    {
      uint32_t location = [self RVAToFileOffset:rva]; 
      NSString * caption = [self findSymbolAtRVA:rva];
      MATCH_STRUCT(protocol_t,location)
      [self createObjC2ProtocolNode:node
                            caption:caption
                           location:location
                           protocol:protocol_t];
    }
  }
  
}

//------------------------------------------------------------------------------
-(void)parseObjC2Class64Pointers:(Pointer64Vector const *)classes
          NonLazyClass64Pointers:(Pointer64Vector const *)nlClasses
              Category64Pointers:(Pointer64Vector const *)categories
       NonLazyCategory64Pointers:(Pointer64Vector const *)nlcategories
              Protocol64Pointers:(Pointer64Vector const *)protocols
{
  MVNode * node = nil;
  
  for (Pointer64Vector::const_iterator iter = classes->begin(); iter != classes->end(); ++iter)
  {
    uint64_t const & rva64 = *iter;
    if (rva64 && (node = [self sectionNodeContainsRVA64:rva64]))
    {
      uint32_t location = [self RVA64ToFileOffset:rva64];   
      NSString * caption = [self findSymbolAtRVA64:rva64];
      MATCH_STRUCT(class64_t,location)
      [self createObjC2Class64Node:node
                           caption:caption
                          location:location
                             class:class64_t];
    }
  }

    for (Pointer64Vector::const_iterator iter = nlClasses->begin(); iter != nlClasses->end(); ++iter)
    {
      uint64_t const & rva64 = *iter;
      if (rva64 && (node = [self sectionNodeContainsRVA64:rva64]))
      {
        uint32_t location = [self RVA64ToFileOffset:rva64];
        NSString * caption = [self findSymbolAtRVA64:rva64];
        MATCH_STRUCT(class64_t,location)
        [self createObjC2Class64Node:node
                             caption:caption
                            location:location
                               class:class64_t];
      }
    }
  
  for (Pointer64Vector::const_iterator iter = categories->begin(); iter != categories->end(); ++iter)
  {
    uint64_t const & rva64 = *iter;
    if (rva64 && (node = [self sectionNodeContainsRVA64:rva64]))
    {
      uint32_t location = [self RVA64ToFileOffset:rva64]; 
      NSString * caption = [self findSymbolAtRVA64:rva64];
      MATCH_STRUCT(category64_t,location)
      [self createObjC2Category64Node:node
                              caption:caption
                             location:location
                             category:category64_t];
    }
  }

    for (Pointer64Vector::const_iterator iter = nlcategories->begin(); iter != nlcategories->end(); ++iter)
    {
      uint64_t const & rva64 = *iter;
      if (rva64 && (node = [self sectionNodeContainsRVA64:rva64]))
      {
        uint32_t location = [self RVA64ToFileOffset:rva64];
        NSString * caption = [self findSymbolAtRVA64:rva64];
        MATCH_STRUCT(category64_t,location)
        [self createObjC2Category64Node:node
                                caption:caption
                               location:location
                               category:category64_t];
      }
    }
  
  for (Pointer64Vector::const_iterator iter = protocols->begin(); iter != protocols->end(); ++iter)
  {
    uint64_t const & rva64 = *iter;
    if (rva64 && (node = [self sectionNodeContainsRVA64:rva64]))
    {
      uint32_t location = [self RVA64ToFileOffset:rva64];  
      NSString * caption = [self findSymbolAtRVA64:rva64];
      MATCH_STRUCT(protocol64_t,location)
      [self createObjC2Protocol64Node:node
                              caption:caption
                             location:location
                             protocol:protocol64_t];
    }
  }
  
}

@end
