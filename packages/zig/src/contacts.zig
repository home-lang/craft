const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;

/// Cross-platform contacts/address book module for Craft framework
/// Provides unified API for iOS Contacts framework, Android ContactsContract, and desktop address books

// ============================================================================
// Types and Enums
// ============================================================================

/// Contact phone number types
pub const PhoneType = enum {
    mobile,
    home,
    work,
    main,
    home_fax,
    work_fax,
    pager,
    other,

    pub fn toString(self: PhoneType) []const u8 {
        return switch (self) {
            .mobile => "mobile",
            .home => "home",
            .work => "work",
            .main => "main",
            .home_fax => "home_fax",
            .work_fax => "work_fax",
            .pager => "pager",
            .other => "other",
        };
    }
};

/// Contact email types
pub const EmailType = enum {
    home,
    work,
    school,
    other,

    pub fn toString(self: EmailType) []const u8 {
        return switch (self) {
            .home => "home",
            .work => "work",
            .school => "school",
            .other => "other",
        };
    }
};

/// Contact address types
pub const AddressType = enum {
    home,
    work,
    other,

    pub fn toString(self: AddressType) []const u8 {
        return switch (self) {
            .home => "home",
            .work => "work",
            .other => "other",
        };
    }
};

/// Social profile types
pub const SocialProfileType = enum {
    facebook,
    twitter,
    linkedin,
    instagram,
    github,
    other,

    pub fn toString(self: SocialProfileType) []const u8 {
        return switch (self) {
            .facebook => "facebook",
            .twitter => "twitter",
            .linkedin => "linkedin",
            .instagram => "instagram",
            .github => "github",
            .other => "other",
        };
    }
};

/// Phone number with type label
pub const PhoneNumber = struct {
    number: []const u8,
    phone_type: PhoneType,
    label: ?[]const u8 = null,
    is_primary: bool = false,

    pub fn format(self: PhoneNumber, allocator: Allocator) ![]u8 {
        const type_str = self.phone_type.toString();
        if (self.label) |label| {
            return std.fmt.allocPrint(allocator, "{s} ({s}): {s}", .{ type_str, label, self.number });
        }
        return std.fmt.allocPrint(allocator, "{s}: {s}", .{ type_str, self.number });
    }
};

/// Email address with type label
pub const EmailAddress = struct {
    email: []const u8,
    email_type: EmailType,
    label: ?[]const u8 = null,
    is_primary: bool = false,

    pub fn isValid(self: EmailAddress) bool {
        // Basic email validation
        const at_pos = std.mem.indexOf(u8, self.email, "@");
        if (at_pos) |pos| {
            if (pos == 0 or pos == self.email.len - 1) return false;
            const domain = self.email[pos + 1 ..];
            const dot_pos = std.mem.indexOf(u8, domain, ".");
            if (dot_pos) |dpos| {
                return dpos > 0 and dpos < domain.len - 1;
            }
        }
        return false;
    }
};

/// Postal address
pub const PostalAddress = struct {
    street: ?[]const u8 = null,
    city: ?[]const u8 = null,
    state: ?[]const u8 = null,
    postal_code: ?[]const u8 = null,
    country: ?[]const u8 = null,
    address_type: AddressType,
    label: ?[]const u8 = null,
    is_primary: bool = false,

    pub fn format(self: PostalAddress, allocator: Allocator) ![]u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(allocator);

        var first = true;
        const parts = [_]?[]const u8{ self.street, self.city, self.state, self.postal_code, self.country };
        for (parts) |maybe_part| {
            if (maybe_part) |part| {
                if (!first) {
                    try result.appendSlice(allocator, ", ");
                }
                try result.appendSlice(allocator, part);
                first = false;
            }
        }

        return result.toOwnedSlice(allocator);
    }

    pub fn isEmpty(self: PostalAddress) bool {
        return self.street == null and self.city == null and
            self.state == null and self.postal_code == null and
            self.country == null;
    }
};

/// Social profile
pub const SocialProfile = struct {
    username: []const u8,
    profile_type: SocialProfileType,
    url: ?[]const u8 = null,
    label: ?[]const u8 = null,
};

/// Instant messaging account
pub const InstantMessage = struct {
    handle: []const u8,
    service: []const u8,
    label: ?[]const u8 = null,
};

/// Contact organization info
pub const Organization = struct {
    name: ?[]const u8 = null,
    department: ?[]const u8 = null,
    job_title: ?[]const u8 = null,

    pub fn isEmpty(self: Organization) bool {
        return self.name == null and self.department == null and self.job_title == null;
    }
};

/// Date component (birthday, anniversary, etc.)
pub const DateComponent = struct {
    year: ?u16 = null,
    month: u8,
    day: u8,
    label: ?[]const u8 = null,

    pub fn format(self: DateComponent, allocator: Allocator) ![]u8 {
        if (self.year) |y| {
            return std.fmt.allocPrint(allocator, "{d:0>4}-{d:0>2}-{d:0>2}", .{ y, self.month, self.day });
        }
        return std.fmt.allocPrint(allocator, "--{d:0>2}-{d:0>2}", .{ self.month, self.day });
    }

    pub fn isValid(self: DateComponent) bool {
        if (self.month < 1 or self.month > 12) return false;
        const days_in_month: u8 = switch (self.month) {
            1, 3, 5, 7, 8, 10, 12 => 31,
            4, 6, 9, 11 => 30,
            2 => if (self.year) |y| (if (isLeapYear(y)) @as(u8, 29) else @as(u8, 28)) else 29,
            else => return false,
        };
        return self.day >= 1 and self.day <= days_in_month;
    }

    fn isLeapYear(year: u16) bool {
        return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
    }
};

/// Relationship type
pub const RelationType = enum {
    spouse,
    child,
    parent,
    sibling,
    friend,
    assistant,
    manager,
    partner,
    other,
};

/// Related person
pub const RelatedPerson = struct {
    name: []const u8,
    relation_type: RelationType,
    label: ?[]const u8 = null,
};

/// Full contact record
pub const Contact = struct {
    id: ?[]const u8 = null,
    identifier: ?[]const u8 = null,

    // Name components
    prefix: ?[]const u8 = null,
    given_name: ?[]const u8 = null,
    middle_name: ?[]const u8 = null,
    family_name: ?[]const u8 = null,
    suffix: ?[]const u8 = null,
    nickname: ?[]const u8 = null,
    phonetic_given_name: ?[]const u8 = null,
    phonetic_family_name: ?[]const u8 = null,

    // Organization
    organization: ?Organization = null,

    // Contact methods
    phone_numbers: []PhoneNumber = &[_]PhoneNumber{},
    email_addresses: []EmailAddress = &[_]EmailAddress{},
    postal_addresses: []PostalAddress = &[_]PostalAddress{},

    // Online presence
    social_profiles: []SocialProfile = &[_]SocialProfile{},
    instant_messages: []InstantMessage = &[_]InstantMessage{},
    urls: [][]const u8 = &[_][]const u8{},

    // Dates
    birthday: ?DateComponent = null,
    dates: []DateComponent = &[_]DateComponent{},

    // Relationships
    related_people: []RelatedPerson = &[_]RelatedPerson{},

    // Other
    note: ?[]const u8 = null,
    image_data: ?[]const u8 = null,
    thumbnail_data: ?[]const u8 = null,

    // Metadata
    created_at: ?i64 = null,
    updated_at: ?i64 = null,

    /// Get full name
    pub fn getFullName(self: Contact, allocator: Allocator) ![]u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(allocator);

        var first = true;
        const parts = [_]?[]const u8{ self.prefix, self.given_name, self.middle_name, self.family_name, self.suffix };
        for (parts) |maybe_part| {
            if (maybe_part) |part| {
                if (!first) {
                    try result.append(allocator, ' ');
                }
                try result.appendSlice(allocator, part);
                first = false;
            }
        }

        if (result.items.len == 0) {
            if (self.organization) |org| {
                if (org.name) |name| return allocator.dupe(u8, name);
            }
            return allocator.dupe(u8, "");
        }

        return result.toOwnedSlice(allocator);
    }

    /// Get display name (short form)
    pub fn getDisplayName(self: Contact, allocator: Allocator) ![]u8 {
        if (self.given_name) |given| {
            if (self.family_name) |family| {
                return std.fmt.allocPrint(allocator, "{s} {s}", .{ given, family });
            }
            return allocator.dupe(u8, given);
        }
        if (self.family_name) |family| {
            return allocator.dupe(u8, family);
        }
        if (self.nickname) |nick| {
            return allocator.dupe(u8, nick);
        }
        if (self.organization) |org| {
            if (org.name) |name| return allocator.dupe(u8, name);
        }
        return allocator.dupe(u8, "Unknown");
    }

    /// Get primary phone number
    pub fn getPrimaryPhone(self: Contact) ?PhoneNumber {
        for (self.phone_numbers) |phone| {
            if (phone.is_primary) return phone;
        }
        if (self.phone_numbers.len > 0) return self.phone_numbers[0];
        return null;
    }

    /// Get primary email
    pub fn getPrimaryEmail(self: Contact) ?EmailAddress {
        for (self.email_addresses) |email| {
            if (email.is_primary) return email;
        }
        if (self.email_addresses.len > 0) return self.email_addresses[0];
        return null;
    }

    /// Get primary address
    pub fn getPrimaryAddress(self: Contact) ?PostalAddress {
        for (self.postal_addresses) |addr| {
            if (addr.is_primary) return addr;
        }
        if (self.postal_addresses.len > 0) return self.postal_addresses[0];
        return null;
    }

    /// Check if contact has minimal info
    pub fn hasMinimalInfo(self: Contact) bool {
        return self.given_name != null or
            self.family_name != null or
            (self.organization != null and !self.organization.?.isEmpty()) or
            self.phone_numbers.len > 0 or
            self.email_addresses.len > 0;
    }
};

/// Contact group/label
pub const ContactGroup = struct {
    id: ?[]const u8 = null,
    name: []const u8,
    contact_count: usize = 0,
    is_system: bool = false,

    pub fn isEmpty(self: ContactGroup) bool {
        return self.contact_count == 0;
    }
};

/// Contact search criteria
pub const SearchCriteria = struct {
    query: ?[]const u8 = null,
    group_id: ?[]const u8 = null,
    has_phone: ?bool = null,
    has_email: ?bool = null,
    has_address: ?bool = null,
    limit: ?usize = null,
    offset: ?usize = null,
};

/// Contact sort field
pub const SortField = enum {
    given_name,
    family_name,
    organization,
    created_at,
    updated_at,
};

/// Contact sort order
pub const SortOrder = enum {
    ascending,
    descending,
};

/// Contact change type
pub const ChangeType = enum {
    added,
    updated,
    deleted,
};

/// Contact change event
pub const ContactChange = struct {
    contact_id: []const u8,
    change_type: ChangeType,
    timestamp: i64,
};

/// Contact authorization status
pub const AuthorizationStatus = enum {
    not_determined,
    restricted,
    denied,
    authorized,

    pub fn isGranted(self: AuthorizationStatus) bool {
        return self == .authorized;
    }
};

/// Contacts error
pub const ContactsError = error{
    NotAuthorized,
    ContactNotFound,
    GroupNotFound,
    InvalidData,
    SaveFailed,
    DeleteFailed,
    DuplicateContact,
    StorageError,
    NetworkError,
    Timeout,
    Unknown,
};

// ============================================================================
// Platform Detection
// ============================================================================

fn getTimestampMs() i64 {
    var ts: std.c.timespec = undefined;
    if (std.c.clock_gettime(.REALTIME, &ts) == 0) {
        return @as(i64, ts.sec) * 1000 + @divTrunc(ts.nsec, 1_000_000);
    }
    return 0;
}

const Platform = enum {
    ios,
    android,
    macos,
    windows,
    linux,
    unknown,
};

fn detectPlatform() Platform {
    return switch (builtin.os.tag) {
        .macos => .macos,
        .ios => .ios,
        .linux => if (builtin.abi == .android) .android else .linux,
        .windows => .windows,
        else => .unknown,
    };
}

// ============================================================================
// Contact Store
// ============================================================================

/// Main contact store interface
pub const ContactStore = struct {
    allocator: Allocator,
    platform: Platform,
    authorization_status: AuthorizationStatus,
    contacts: std.ArrayListUnmanaged(Contact) = .{},
    groups: std.ArrayListUnmanaged(ContactGroup) = .{},
    change_history: std.ArrayListUnmanaged(ContactChange) = .{},
    last_sync: ?i64,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .platform = detectPlatform(),
            .authorization_status = .not_determined,
            .last_sync = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.contacts.deinit(self.allocator);
        self.groups.deinit(self.allocator);
        self.change_history.deinit(self.allocator);
    }

    /// Request authorization to access contacts
    pub fn requestAuthorization(self: *Self) !AuthorizationStatus {
        // Simulate authorization request
        switch (self.platform) {
            .ios, .macos => {
                // CNContactStore.requestAccess
                self.authorization_status = .authorized;
            },
            .android => {
                // ActivityCompat.requestPermissions
                self.authorization_status = .authorized;
            },
            else => {
                self.authorization_status = .authorized;
            },
        }
        return self.authorization_status;
    }

    /// Check current authorization status
    pub fn getAuthorizationStatus(self: Self) AuthorizationStatus {
        return self.authorization_status;
    }

    /// Fetch all contacts
    pub fn fetchAllContacts(self: *Self, sort_field: SortField, sort_order: SortOrder) ![]Contact {
        if (!self.authorization_status.isGranted()) {
            return ContactsError.NotAuthorized;
        }

        // Sort contacts
        const items = self.contacts.items;
        const Context = struct {
            field: SortField,
            order: SortOrder,
        };
        const ctx = Context{ .field = sort_field, .order = sort_order };

        std.mem.sort(Contact, items, ctx, struct {
            fn lessThan(context: Context, a: Contact, b: Contact) bool {
                const cmp = switch (context.field) {
                    .given_name => blk: {
                        const a_name = a.given_name orelse "";
                        const b_name = b.given_name orelse "";
                        break :blk std.mem.order(u8, a_name, b_name);
                    },
                    .family_name => blk: {
                        const a_name = a.family_name orelse "";
                        const b_name = b.family_name orelse "";
                        break :blk std.mem.order(u8, a_name, b_name);
                    },
                    .organization => blk: {
                        const a_org = if (a.organization) |o| o.name orelse "" else "";
                        const b_org = if (b.organization) |o| o.name orelse "" else "";
                        break :blk std.mem.order(u8, a_org, b_org);
                    },
                    .created_at => blk: {
                        const a_time = a.created_at orelse 0;
                        const b_time = b.created_at orelse 0;
                        break :blk std.math.order(a_time, b_time);
                    },
                    .updated_at => blk: {
                        const a_time = a.updated_at orelse 0;
                        const b_time = b.updated_at orelse 0;
                        break :blk std.math.order(a_time, b_time);
                    },
                };

                return switch (context.order) {
                    .ascending => cmp == .lt,
                    .descending => cmp == .gt,
                };
            }
        }.lessThan);

        return items;
    }

    /// Search contacts
    pub fn searchContacts(self: *Self, criteria: SearchCriteria) ![]Contact {
        if (!self.authorization_status.isGranted()) {
            return ContactsError.NotAuthorized;
        }

        var results = std.ArrayListUnmanaged(Contact){};
        errdefer results.deinit(self.allocator);

        for (self.contacts.items) |contact| {
            if (self.matchesCriteria(contact, criteria)) {
                try results.append(self.allocator, contact);
            }
        }

        // Apply limit and offset
        var start: usize = 0;
        var end: usize = results.items.len;

        if (criteria.offset) |offset| {
            start = @min(offset, results.items.len);
        }
        if (criteria.limit) |limit| {
            end = @min(start + limit, results.items.len);
        }

        return results.items[start..end];
    }

    fn matchesCriteria(self: *Self, contact: Contact, criteria: SearchCriteria) bool {
        // Query match
        if (criteria.query) |query| {
            const name = contact.getDisplayName(self.allocator) catch return false;
            defer self.allocator.free(name);

            var lower_name = self.allocator.alloc(u8, name.len) catch return false;
            defer self.allocator.free(lower_name);
            for (name, 0..) |c, i| {
                lower_name[i] = std.ascii.toLower(c);
            }

            var lower_query = self.allocator.alloc(u8, query.len) catch return false;
            defer self.allocator.free(lower_query);
            for (query, 0..) |c, i| {
                lower_query[i] = std.ascii.toLower(c);
            }

            if (std.mem.indexOf(u8, lower_name, lower_query) == null) {
                return false;
            }
        }

        // Filter by has_phone
        if (criteria.has_phone) |has| {
            if (has and contact.phone_numbers.len == 0) return false;
            if (!has and contact.phone_numbers.len > 0) return false;
        }

        // Filter by has_email
        if (criteria.has_email) |has| {
            if (has and contact.email_addresses.len == 0) return false;
            if (!has and contact.email_addresses.len > 0) return false;
        }

        // Filter by has_address
        if (criteria.has_address) |has| {
            if (has and contact.postal_addresses.len == 0) return false;
            if (!has and contact.postal_addresses.len > 0) return false;
        }

        return true;
    }

    /// Get contact by ID
    pub fn getContact(self: *Self, contact_id: []const u8) !Contact {
        if (!self.authorization_status.isGranted()) {
            return ContactsError.NotAuthorized;
        }

        for (self.contacts.items) |contact| {
            if (contact.id) |id| {
                if (std.mem.eql(u8, id, contact_id)) {
                    return contact;
                }
            }
        }
        return ContactsError.ContactNotFound;
    }

    /// Add a new contact
    pub fn addContact(self: *Self, contact: Contact) ![]const u8 {
        if (!self.authorization_status.isGranted()) {
            return ContactsError.NotAuthorized;
        }

        var new_contact = contact;
        const timestamp = getTimestampMs();

        // Generate ID
        const id = try std.fmt.allocPrint(self.allocator, "contact_{d}", .{timestamp});
        new_contact.id = id;
        new_contact.created_at = timestamp;
        new_contact.updated_at = timestamp;

        try self.contacts.append(self.allocator, new_contact);

        // Record change
        try self.change_history.append(self.allocator, .{
            .contact_id = id,
            .change_type = .added,
            .timestamp = timestamp,
        });

        return id;
    }

    /// Update an existing contact
    pub fn updateContact(self: *Self, contact_id: []const u8, updates: Contact) !void {
        if (!self.authorization_status.isGranted()) {
            return ContactsError.NotAuthorized;
        }

        for (self.contacts.items, 0..) |*contact, i| {
            if (contact.id) |id| {
                if (std.mem.eql(u8, id, contact_id)) {
                    const timestamp = getTimestampMs();

                    // Apply updates
                    var updated = updates;
                    updated.id = contact.id;
                    updated.created_at = contact.created_at;
                    updated.updated_at = timestamp;

                    self.contacts.items[i] = updated;

                    // Record change
                    try self.change_history.append(self.allocator, .{
                        .contact_id = contact_id,
                        .change_type = .updated,
                        .timestamp = timestamp,
                    });

                    return;
                }
            }
        }
        return ContactsError.ContactNotFound;
    }

    /// Delete a contact
    pub fn deleteContact(self: *Self, contact_id: []const u8) !void {
        if (!self.authorization_status.isGranted()) {
            return ContactsError.NotAuthorized;
        }

        for (self.contacts.items, 0..) |contact, i| {
            if (contact.id) |id| {
                if (std.mem.eql(u8, id, contact_id)) {
                    const timestamp = getTimestampMs();

                    _ = self.contacts.orderedRemove(i);

                    // Record change
                    try self.change_history.append(self.allocator, .{
                        .contact_id = contact_id,
                        .change_type = .deleted,
                        .timestamp = timestamp,
                    });

                    return;
                }
            }
        }
        return ContactsError.ContactNotFound;
    }

    /// Get all groups
    pub fn getGroups(self: *Self) ![]ContactGroup {
        if (!self.authorization_status.isGranted()) {
            return ContactsError.NotAuthorized;
        }
        return self.groups.items;
    }

    /// Create a new group
    pub fn createGroup(self: *Self, name: []const u8) ![]const u8 {
        if (!self.authorization_status.isGranted()) {
            return ContactsError.NotAuthorized;
        }

        const timestamp = getTimestampMs();
        const id = try std.fmt.allocPrint(self.allocator, "group_{d}", .{timestamp});

        try self.groups.append(self.allocator, .{
            .id = id,
            .name = name,
            .contact_count = 0,
            .is_system = false,
        });

        return id;
    }

    /// Delete a group
    pub fn deleteGroup(self: *Self, group_id: []const u8) !void {
        if (!self.authorization_status.isGranted()) {
            return ContactsError.NotAuthorized;
        }

        for (self.groups.items, 0..) |group, i| {
            if (group.id) |id| {
                if (std.mem.eql(u8, id, group_id)) {
                    if (group.is_system) {
                        return ContactsError.DeleteFailed;
                    }
                    _ = self.groups.orderedRemove(i);
                    return;
                }
            }
        }
        return ContactsError.GroupNotFound;
    }

    /// Get change history since timestamp
    pub fn getChangesSince(self: *Self, since: i64) ![]ContactChange {
        if (!self.authorization_status.isGranted()) {
            return ContactsError.NotAuthorized;
        }

        var changes = std.ArrayListUnmanaged(ContactChange){};
        errdefer changes.deinit(self.allocator);

        for (self.change_history.items) |change| {
            if (change.timestamp > since) {
                try changes.append(self.allocator, change);
            }
        }

        return changes.items;
    }

    /// Get contact count
    pub fn getContactCount(self: Self) usize {
        return self.contacts.items.len;
    }

    /// Get group count
    pub fn getGroupCount(self: Self) usize {
        return self.groups.items.len;
    }
};

// ============================================================================
// Contact Builder
// ============================================================================

/// Helper for building contacts
pub const ContactBuilder = struct {
    allocator: Allocator,
    contact: Contact,
    phone_numbers: std.ArrayListUnmanaged(PhoneNumber) = .{},
    email_addresses: std.ArrayListUnmanaged(EmailAddress) = .{},
    postal_addresses: std.ArrayListUnmanaged(PostalAddress) = .{},
    social_profiles: std.ArrayListUnmanaged(SocialProfile) = .{},

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return .{
            .allocator = allocator,
            .contact = .{},
        };
    }

    pub fn deinit(self: *Self) void {
        self.phone_numbers.deinit(self.allocator);
        self.email_addresses.deinit(self.allocator);
        self.postal_addresses.deinit(self.allocator);
        self.social_profiles.deinit(self.allocator);
    }

    pub fn setGivenName(self: *Self, name: []const u8) *Self {
        self.contact.given_name = name;
        return self;
    }

    pub fn setFamilyName(self: *Self, name: []const u8) *Self {
        self.contact.family_name = name;
        return self;
    }

    pub fn setMiddleName(self: *Self, name: []const u8) *Self {
        self.contact.middle_name = name;
        return self;
    }

    pub fn setNickname(self: *Self, name: []const u8) *Self {
        self.contact.nickname = name;
        return self;
    }

    pub fn setPrefix(self: *Self, prefix: []const u8) *Self {
        self.contact.prefix = prefix;
        return self;
    }

    pub fn setSuffix(self: *Self, suffix: []const u8) *Self {
        self.contact.suffix = suffix;
        return self;
    }

    pub fn setOrganization(self: *Self, org: Organization) *Self {
        self.contact.organization = org;
        return self;
    }

    pub fn addPhoneNumber(self: *Self, phone: PhoneNumber) !*Self {
        try self.phone_numbers.append(self.allocator, phone);
        return self;
    }

    pub fn addEmailAddress(self: *Self, email: EmailAddress) !*Self {
        try self.email_addresses.append(self.allocator, email);
        return self;
    }

    pub fn addPostalAddress(self: *Self, address: PostalAddress) !*Self {
        try self.postal_addresses.append(self.allocator, address);
        return self;
    }

    pub fn addSocialProfile(self: *Self, profile: SocialProfile) !*Self {
        try self.social_profiles.append(self.allocator, profile);
        return self;
    }

    pub fn setBirthday(self: *Self, birthday: DateComponent) *Self {
        self.contact.birthday = birthday;
        return self;
    }

    pub fn setNote(self: *Self, note: []const u8) *Self {
        self.contact.note = note;
        return self;
    }

    pub fn build(self: *Self) Contact {
        self.contact.phone_numbers = self.phone_numbers.items;
        self.contact.email_addresses = self.email_addresses.items;
        self.contact.postal_addresses = self.postal_addresses.items;
        self.contact.social_profiles = self.social_profiles.items;
        return self.contact;
    }
};

// ============================================================================
// vCard Parser/Generator
// ============================================================================

pub const VCardVersion = enum {
    v2_1,
    v3_0,
    v4_0,
};

/// vCard generator
pub const VCardGenerator = struct {
    allocator: Allocator,
    version: VCardVersion,

    const Self = @This();

    pub fn init(allocator: Allocator, version: VCardVersion) Self {
        return .{
            .allocator = allocator,
            .version = version,
        };
    }

    pub fn generate(self: Self, contact: Contact) ![]u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

        // Begin vCard
        try result.appendSlice(self.allocator, "BEGIN:VCARD\r\n");

        // Version
        const version_str = switch (self.version) {
            .v2_1 => "VERSION:2.1\r\n",
            .v3_0 => "VERSION:3.0\r\n",
            .v4_0 => "VERSION:4.0\r\n",
        };
        try result.appendSlice(self.allocator, version_str);

        // Name
        const fn_name = contact.family_name orelse "";
        const gn_name = contact.given_name orelse "";
        const mn_name = contact.middle_name orelse "";
        const prefix = contact.prefix orelse "";
        const suffix = contact.suffix orelse "";

        const n_line = try std.fmt.allocPrint(self.allocator, "N:{s};{s};{s};{s};{s}\r\n", .{ fn_name, gn_name, mn_name, prefix, suffix });
        defer self.allocator.free(n_line);
        try result.appendSlice(self.allocator, n_line);

        // Full name
        const full_name = try contact.getDisplayName(self.allocator);
        defer self.allocator.free(full_name);
        const fn_line = try std.fmt.allocPrint(self.allocator, "FN:{s}\r\n", .{full_name});
        defer self.allocator.free(fn_line);
        try result.appendSlice(self.allocator, fn_line);

        // Organization
        if (contact.organization) |org| {
            if (org.name) |name| {
                const org_line = try std.fmt.allocPrint(self.allocator, "ORG:{s}\r\n", .{name});
                defer self.allocator.free(org_line);
                try result.appendSlice(self.allocator, org_line);
            }
            if (org.job_title) |title| {
                const title_line = try std.fmt.allocPrint(self.allocator, "TITLE:{s}\r\n", .{title});
                defer self.allocator.free(title_line);
                try result.appendSlice(self.allocator, title_line);
            }
        }

        // Phone numbers
        for (contact.phone_numbers) |phone| {
            var type_buf: [16]u8 = undefined;
            const type_str = phone.phone_type.toString();
            for (type_str, 0..) |c, i| {
                type_buf[i] = std.ascii.toUpper(c);
            }
            const tel_line = try std.fmt.allocPrint(self.allocator, "TEL;TYPE={s}:{s}\r\n", .{ type_buf[0..type_str.len], phone.number });
            defer self.allocator.free(tel_line);
            try result.appendSlice(self.allocator, tel_line);
        }

        // Email addresses
        for (contact.email_addresses) |email| {
            var type_buf: [16]u8 = undefined;
            const type_str = email.email_type.toString();
            for (type_str, 0..) |c, i| {
                type_buf[i] = std.ascii.toUpper(c);
            }
            const email_line = try std.fmt.allocPrint(self.allocator, "EMAIL;TYPE={s}:{s}\r\n", .{ type_buf[0..type_str.len], email.email });
            defer self.allocator.free(email_line);
            try result.appendSlice(self.allocator, email_line);
        }

        // Note
        if (contact.note) |note| {
            const note_line = try std.fmt.allocPrint(self.allocator, "NOTE:{s}\r\n", .{note});
            defer self.allocator.free(note_line);
            try result.appendSlice(self.allocator, note_line);
        }

        // End vCard
        try result.appendSlice(self.allocator, "END:VCARD\r\n");

        return result.toOwnedSlice(self.allocator);
    }
};

// ============================================================================
// Contact Deduplication
// ============================================================================

pub const DeduplicationStrategy = enum {
    exact_match,
    fuzzy_match,
    phone_match,
    email_match,
};

pub const DuplicatePair = struct {
    contact1_id: []const u8,
    contact2_id: []const u8,
    confidence: f32,
    match_reason: []const u8,
};

pub fn findDuplicates(allocator: Allocator, contacts: []Contact, strategy: DeduplicationStrategy) ![]DuplicatePair {
    var duplicates = std.ArrayListUnmanaged(DuplicatePair){};
    errdefer duplicates.deinit(allocator);

    for (contacts, 0..) |contact1, i| {
        for (contacts[i + 1 ..]) |contact2| {
            const match = switch (strategy) {
                .exact_match => checkExactMatch(contact1, contact2, allocator),
                .fuzzy_match => checkFuzzyMatch(contact1, contact2),
                .phone_match => checkPhoneMatch(contact1, contact2),
                .email_match => checkEmailMatch(contact1, contact2),
            };

            if (match.confidence > 0.8) {
                try duplicates.append(allocator, .{
                    .contact1_id = contact1.id orelse "unknown",
                    .contact2_id = contact2.id orelse "unknown",
                    .confidence = match.confidence,
                    .match_reason = match.reason,
                });
            }
        }
    }

    return duplicates.items;
}

const MatchResult = struct {
    confidence: f32,
    reason: []const u8,
};

fn checkExactMatch(contact1: Contact, contact2: Contact, allocator: Allocator) MatchResult {
    const name1 = contact1.getDisplayName(allocator) catch return .{ .confidence = 0, .reason = "" };
    defer allocator.free(name1);
    const name2 = contact2.getDisplayName(allocator) catch return .{ .confidence = 0, .reason = "" };
    defer allocator.free(name2);

    if (std.mem.eql(u8, name1, name2)) {
        return .{ .confidence = 1.0, .reason = "exact_name" };
    }
    return .{ .confidence = 0, .reason = "" };
}

fn checkFuzzyMatch(contact1: Contact, contact2: Contact) MatchResult {
    // Simple fuzzy matching based on name components
    var score: f32 = 0;

    if (contact1.given_name != null and contact2.given_name != null) {
        if (std.mem.eql(u8, contact1.given_name.?, contact2.given_name.?)) {
            score += 0.4;
        }
    }

    if (contact1.family_name != null and contact2.family_name != null) {
        if (std.mem.eql(u8, contact1.family_name.?, contact2.family_name.?)) {
            score += 0.4;
        }
    }

    if (score > 0) {
        return .{ .confidence = score, .reason = "fuzzy_name" };
    }
    return .{ .confidence = 0, .reason = "" };
}

fn checkPhoneMatch(contact1: Contact, contact2: Contact) MatchResult {
    for (contact1.phone_numbers) |phone1| {
        for (contact2.phone_numbers) |phone2| {
            if (std.mem.eql(u8, phone1.number, phone2.number)) {
                return .{ .confidence = 0.9, .reason = "phone_match" };
            }
        }
    }
    return .{ .confidence = 0, .reason = "" };
}

fn checkEmailMatch(contact1: Contact, contact2: Contact) MatchResult {
    for (contact1.email_addresses) |email1| {
        for (contact2.email_addresses) |email2| {
            if (std.mem.eql(u8, email1.email, email2.email)) {
                return .{ .confidence = 0.95, .reason = "email_match" };
            }
        }
    }
    return .{ .confidence = 0, .reason = "" };
}

// ============================================================================
// Tests
// ============================================================================

test "PhoneType toString" {
    try std.testing.expectEqualStrings("mobile", PhoneType.mobile.toString());
    try std.testing.expectEqualStrings("work", PhoneType.work.toString());
    try std.testing.expectEqualStrings("home_fax", PhoneType.home_fax.toString());
}

test "EmailType toString" {
    try std.testing.expectEqualStrings("home", EmailType.home.toString());
    try std.testing.expectEqualStrings("work", EmailType.work.toString());
    try std.testing.expectEqualStrings("school", EmailType.school.toString());
}

test "EmailAddress validation" {
    const valid = EmailAddress{ .email = "test@example.com", .email_type = .work };
    try std.testing.expect(valid.isValid());

    const invalid1 = EmailAddress{ .email = "invalid", .email_type = .work };
    try std.testing.expect(!invalid1.isValid());

    const invalid2 = EmailAddress{ .email = "@example.com", .email_type = .work };
    try std.testing.expect(!invalid2.isValid());

    const invalid3 = EmailAddress{ .email = "test@", .email_type = .work };
    try std.testing.expect(!invalid3.isValid());
}

test "PostalAddress format" {
    const allocator = std.testing.allocator;

    const addr = PostalAddress{
        .street = "123 Main St",
        .city = "San Francisco",
        .state = "CA",
        .postal_code = "94105",
        .country = "USA",
        .address_type = .home,
    };

    const formatted = try addr.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expectEqualStrings("123 Main St, San Francisco, CA, 94105, USA", formatted);
}

test "PostalAddress isEmpty" {
    const empty = PostalAddress{ .address_type = .home };
    try std.testing.expect(empty.isEmpty());

    const not_empty = PostalAddress{
        .city = "New York",
        .address_type = .work,
    };
    try std.testing.expect(!not_empty.isEmpty());
}

test "DateComponent format" {
    const allocator = std.testing.allocator;

    const with_year = DateComponent{ .year = 1990, .month = 5, .day = 15 };
    const formatted1 = try with_year.format(allocator);
    defer allocator.free(formatted1);
    try std.testing.expectEqualStrings("1990-05-15", formatted1);

    const without_year = DateComponent{ .month = 12, .day = 25 };
    const formatted2 = try without_year.format(allocator);
    defer allocator.free(formatted2);
    try std.testing.expectEqualStrings("--12-25", formatted2);
}

test "DateComponent validation" {
    const valid = DateComponent{ .year = 2000, .month = 2, .day = 29 };
    try std.testing.expect(valid.isValid());

    const invalid_month = DateComponent{ .month = 13, .day = 1 };
    try std.testing.expect(!invalid_month.isValid());

    const invalid_day = DateComponent{ .month = 2, .day = 30 };
    try std.testing.expect(!invalid_day.isValid());

    const non_leap = DateComponent{ .year = 2001, .month = 2, .day = 29 };
    try std.testing.expect(!non_leap.isValid());
}

test "Organization isEmpty" {
    const empty = Organization{};
    try std.testing.expect(empty.isEmpty());

    const not_empty = Organization{ .name = "Acme Corp" };
    try std.testing.expect(!not_empty.isEmpty());
}

test "Contact getFullName" {
    const allocator = std.testing.allocator;

    const contact = Contact{
        .prefix = "Dr.",
        .given_name = "John",
        .middle_name = "Michael",
        .family_name = "Smith",
        .suffix = "Jr.",
    };

    const full_name = try contact.getFullName(allocator);
    defer allocator.free(full_name);

    try std.testing.expectEqualStrings("Dr. John Michael Smith Jr.", full_name);
}

test "Contact getDisplayName" {
    const allocator = std.testing.allocator;

    const contact = Contact{
        .given_name = "Jane",
        .family_name = "Doe",
    };

    const display_name = try contact.getDisplayName(allocator);
    defer allocator.free(display_name);

    try std.testing.expectEqualStrings("Jane Doe", display_name);
}

test "Contact getDisplayName with organization fallback" {
    const allocator = std.testing.allocator;

    const contact = Contact{
        .organization = .{ .name = "Tech Corp" },
    };

    const display_name = try contact.getDisplayName(allocator);
    defer allocator.free(display_name);

    try std.testing.expectEqualStrings("Tech Corp", display_name);
}

test "Contact getPrimaryPhone" {
    var phones = [_]PhoneNumber{
        .{ .number = "111-1111", .phone_type = .home, .is_primary = false },
        .{ .number = "222-2222", .phone_type = .mobile, .is_primary = true },
    };

    const contact = Contact{
        .given_name = "Test",
        .phone_numbers = &phones,
    };

    const primary = contact.getPrimaryPhone();
    try std.testing.expect(primary != null);
    try std.testing.expectEqualStrings("222-2222", primary.?.number);
}

test "Contact getPrimaryEmail" {
    var emails = [_]EmailAddress{
        .{ .email = "personal@test.com", .email_type = .home, .is_primary = false },
        .{ .email = "work@test.com", .email_type = .work, .is_primary = true },
    };

    const contact = Contact{
        .given_name = "Test",
        .email_addresses = &emails,
    };

    const primary = contact.getPrimaryEmail();
    try std.testing.expect(primary != null);
    try std.testing.expectEqualStrings("work@test.com", primary.?.email);
}

test "Contact hasMinimalInfo" {
    const minimal = Contact{ .given_name = "Test" };
    try std.testing.expect(minimal.hasMinimalInfo());

    const no_info = Contact{};
    try std.testing.expect(!no_info.hasMinimalInfo());

    var phones = [_]PhoneNumber{.{ .number = "123", .phone_type = .mobile }};
    const with_phone = Contact{ .phone_numbers = &phones };
    try std.testing.expect(with_phone.hasMinimalInfo());
}

test "ContactGroup isEmpty" {
    const empty_group = ContactGroup{ .name = "Empty", .contact_count = 0 };
    try std.testing.expect(empty_group.isEmpty());

    const non_empty = ContactGroup{ .name = "Friends", .contact_count = 5 };
    try std.testing.expect(!non_empty.isEmpty());
}

test "AuthorizationStatus isGranted" {
    try std.testing.expect(AuthorizationStatus.authorized.isGranted());
    try std.testing.expect(!AuthorizationStatus.denied.isGranted());
    try std.testing.expect(!AuthorizationStatus.not_determined.isGranted());
    try std.testing.expect(!AuthorizationStatus.restricted.isGranted());
}

test "ContactStore init and deinit" {
    const allocator = std.testing.allocator;
    var store = ContactStore.init(allocator);
    defer store.deinit();

    try std.testing.expect(store.authorization_status == .not_determined);
    try std.testing.expectEqual(@as(usize, 0), store.getContactCount());
}

test "ContactStore requestAuthorization" {
    const allocator = std.testing.allocator;
    var store = ContactStore.init(allocator);
    defer store.deinit();

    const status = try store.requestAuthorization();
    try std.testing.expect(status == .authorized);
    try std.testing.expect(store.getAuthorizationStatus() == .authorized);
}

test "ContactStore addContact" {
    const allocator = std.testing.allocator;
    var store = ContactStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();

    const contact = Contact{
        .given_name = "John",
        .family_name = "Doe",
    };

    const id = try store.addContact(contact);
    try std.testing.expect(id.len > 0);
    try std.testing.expectEqual(@as(usize, 1), store.getContactCount());
}

test "ContactStore getContact" {
    const allocator = std.testing.allocator;
    var store = ContactStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();

    const contact = Contact{
        .given_name = "Jane",
        .family_name = "Smith",
    };

    const id = try store.addContact(contact);
    const retrieved = try store.getContact(id);

    try std.testing.expectEqualStrings("Jane", retrieved.given_name.?);
    try std.testing.expectEqualStrings("Smith", retrieved.family_name.?);
}

test "ContactStore updateContact" {
    const allocator = std.testing.allocator;
    var store = ContactStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();

    const contact = Contact{
        .given_name = "Bob",
        .family_name = "Brown",
    };

    const id = try store.addContact(contact);

    const updates = Contact{
        .given_name = "Robert",
        .family_name = "Brown",
    };

    try store.updateContact(id, updates);

    const updated = try store.getContact(id);
    try std.testing.expectEqualStrings("Robert", updated.given_name.?);
}

test "ContactStore deleteContact" {
    const allocator = std.testing.allocator;
    var store = ContactStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();

    const contact = Contact{
        .given_name = "Delete",
        .family_name = "Me",
    };

    const id = try store.addContact(contact);
    try std.testing.expectEqual(@as(usize, 1), store.getContactCount());

    try store.deleteContact(id);
    try std.testing.expectEqual(@as(usize, 0), store.getContactCount());
}

test "ContactStore operations without authorization" {
    const allocator = std.testing.allocator;
    var store = ContactStore.init(allocator);
    defer store.deinit();

    const contact = Contact{ .given_name = "Test" };

    // Should fail without authorization
    try std.testing.expectError(ContactsError.NotAuthorized, store.addContact(contact));
    try std.testing.expectError(ContactsError.NotAuthorized, store.getContact("any_id"));
}

test "ContactStore createGroup" {
    const allocator = std.testing.allocator;
    var store = ContactStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();

    const id = try store.createGroup("Friends");
    try std.testing.expect(id.len > 0);
    try std.testing.expectEqual(@as(usize, 1), store.getGroupCount());

    const groups = try store.getGroups();
    try std.testing.expectEqualStrings("Friends", groups[0].name);
}

test "ContactStore deleteGroup" {
    const allocator = std.testing.allocator;
    var store = ContactStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();

    const id = try store.createGroup("ToDelete");
    try std.testing.expectEqual(@as(usize, 1), store.getGroupCount());

    try store.deleteGroup(id);
    try std.testing.expectEqual(@as(usize, 0), store.getGroupCount());
}

test "ContactStore change history" {
    const allocator = std.testing.allocator;
    var store = ContactStore.init(allocator);
    defer store.deinit();

    _ = try store.requestAuthorization();

    const start_time = getTimestampMs();

    const contact = Contact{ .given_name = "History" };
    const id = try store.addContact(contact);

    const updates = Contact{ .given_name = "Updated" };
    try store.updateContact(id, updates);

    try store.deleteContact(id);

    const changes = try store.getChangesSince(start_time - 1);
    try std.testing.expectEqual(@as(usize, 3), changes.len);
    try std.testing.expect(changes[0].change_type == .added);
    try std.testing.expect(changes[1].change_type == .updated);
    try std.testing.expect(changes[2].change_type == .deleted);
}

test "ContactBuilder basic usage" {
    const allocator = std.testing.allocator;
    var builder = ContactBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setGivenName("Alice")
        .setFamilyName("Johnson")
        .setNickname("Ali");

    const contact = builder.build();
    try std.testing.expectEqualStrings("Alice", contact.given_name.?);
    try std.testing.expectEqualStrings("Johnson", contact.family_name.?);
    try std.testing.expectEqualStrings("Ali", contact.nickname.?);
}

test "ContactBuilder with phone and email" {
    const allocator = std.testing.allocator;
    var builder = ContactBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setGivenName("Bob");
    _ = try builder.addPhoneNumber(.{ .number = "555-1234", .phone_type = .mobile });
    _ = try builder.addEmailAddress(.{ .email = "bob@test.com", .email_type = .work });

    const contact = builder.build();
    try std.testing.expectEqual(@as(usize, 1), contact.phone_numbers.len);
    try std.testing.expectEqual(@as(usize, 1), contact.email_addresses.len);
}

test "ContactBuilder with organization" {
    const allocator = std.testing.allocator;
    var builder = ContactBuilder.init(allocator);
    defer builder.deinit();

    _ = builder.setGivenName("Charlie")
        .setOrganization(.{
        .name = "Acme Inc",
        .department = "Engineering",
        .job_title = "Software Developer",
    });

    const contact = builder.build();
    try std.testing.expect(contact.organization != null);
    try std.testing.expectEqualStrings("Acme Inc", contact.organization.?.name.?);
    try std.testing.expectEqualStrings("Software Developer", contact.organization.?.job_title.?);
}

test "VCardGenerator basic" {
    const allocator = std.testing.allocator;
    const generator = VCardGenerator.init(allocator, .v3_0);

    const contact = Contact{
        .given_name = "Test",
        .family_name = "User",
    };

    const vcard = try generator.generate(contact);
    defer allocator.free(vcard);

    try std.testing.expect(std.mem.indexOf(u8, vcard, "BEGIN:VCARD") != null);
    try std.testing.expect(std.mem.indexOf(u8, vcard, "VERSION:3.0") != null);
    try std.testing.expect(std.mem.indexOf(u8, vcard, "END:VCARD") != null);
    try std.testing.expect(std.mem.indexOf(u8, vcard, "FN:Test User") != null);
}

test "VCardGenerator with organization" {
    const allocator = std.testing.allocator;
    const generator = VCardGenerator.init(allocator, .v4_0);

    const contact = Contact{
        .given_name = "Employee",
        .family_name = "Test",
        .organization = .{
            .name = "Test Corp",
            .job_title = "Manager",
        },
    };

    const vcard = try generator.generate(contact);
    defer allocator.free(vcard);

    try std.testing.expect(std.mem.indexOf(u8, vcard, "ORG:Test Corp") != null);
    try std.testing.expect(std.mem.indexOf(u8, vcard, "TITLE:Manager") != null);
}

test "duplicate detection exact match" {
    const allocator = std.testing.allocator;

    var contacts = [_]Contact{
        .{ .id = "1", .given_name = "John", .family_name = "Doe" },
        .{ .id = "2", .given_name = "John", .family_name = "Doe" },
        .{ .id = "3", .given_name = "Jane", .family_name = "Smith" },
    };

    const duplicates = try findDuplicates(allocator, &contacts, .exact_match);
    try std.testing.expectEqual(@as(usize, 1), duplicates.len);
    try std.testing.expect(duplicates[0].confidence == 1.0);
}

test "duplicate detection phone match" {
    const allocator = std.testing.allocator;

    var phone1 = [_]PhoneNumber{.{ .number = "555-1234", .phone_type = .mobile }};
    var phone2 = [_]PhoneNumber{.{ .number = "555-1234", .phone_type = .work }};
    var phone3 = [_]PhoneNumber{.{ .number = "555-5678", .phone_type = .mobile }};

    var contacts = [_]Contact{
        .{ .id = "1", .given_name = "Alice", .phone_numbers = &phone1 },
        .{ .id = "2", .given_name = "Bob", .phone_numbers = &phone2 },
        .{ .id = "3", .given_name = "Charlie", .phone_numbers = &phone3 },
    };

    const duplicates = try findDuplicates(allocator, &contacts, .phone_match);
    try std.testing.expectEqual(@as(usize, 1), duplicates.len);
    try std.testing.expect(duplicates[0].confidence == 0.9);
}

test "duplicate detection email match" {
    const allocator = std.testing.allocator;

    var email1 = [_]EmailAddress{.{ .email = "shared@test.com", .email_type = .work }};
    var email2 = [_]EmailAddress{.{ .email = "shared@test.com", .email_type = .home }};
    var email3 = [_]EmailAddress{.{ .email = "different@test.com", .email_type = .work }};

    var contacts = [_]Contact{
        .{ .id = "1", .given_name = "Dave", .email_addresses = &email1 },
        .{ .id = "2", .given_name = "Eve", .email_addresses = &email2 },
        .{ .id = "3", .given_name = "Frank", .email_addresses = &email3 },
    };

    const duplicates = try findDuplicates(allocator, &contacts, .email_match);
    try std.testing.expectEqual(@as(usize, 1), duplicates.len);
    try std.testing.expect(duplicates[0].confidence == 0.95);
}

test "SocialProfileType toString" {
    try std.testing.expectEqualStrings("facebook", SocialProfileType.facebook.toString());
    try std.testing.expectEqualStrings("twitter", SocialProfileType.twitter.toString());
    try std.testing.expectEqualStrings("linkedin", SocialProfileType.linkedin.toString());
}

test "AddressType toString" {
    try std.testing.expectEqualStrings("home", AddressType.home.toString());
    try std.testing.expectEqualStrings("work", AddressType.work.toString());
    try std.testing.expectEqualStrings("other", AddressType.other.toString());
}

test "PhoneNumber format" {
    const allocator = std.testing.allocator;

    const phone = PhoneNumber{
        .number = "555-1234",
        .phone_type = .mobile,
    };

    const formatted = try phone.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expectEqualStrings("mobile: 555-1234", formatted);
}

test "PhoneNumber format with label" {
    const allocator = std.testing.allocator;

    const phone = PhoneNumber{
        .number = "555-5678",
        .phone_type = .work,
        .label = "Direct Line",
    };

    const formatted = try phone.format(allocator);
    defer allocator.free(formatted);

    try std.testing.expectEqualStrings("work (Direct Line): 555-5678", formatted);
}

test "platform detection" {
    const platform = detectPlatform();
    // Should detect macOS on this machine
    try std.testing.expect(platform == .macos or platform == .linux or platform == .windows or platform == .unknown);
}

test "timestamp generation" {
    const ts1 = getTimestampMs();
    const ts2 = getTimestampMs();
    try std.testing.expect(ts2 >= ts1);
    try std.testing.expect(ts1 > 0);
}
