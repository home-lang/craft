const std = @import("std");
const base = @import("base.zig");
const Component = base.Component;
const ComponentProps = base.ComponentProps;

/// Stepper Component - Multi-step progress indicator and navigation
pub const Stepper = struct {
    component: Component,
    steps: std.ArrayList(Step),
    current_step: usize,
    orientation: Orientation,
    linear: bool,
    on_step_change: ?*const fn (usize, usize) void,
    show_step_numbers: bool,
    allow_click_navigation: bool,

    pub const Step = struct {
        label: []const u8,
        description: ?[]const u8 = null,
        icon: ?[]const u8 = null,
        status: Status = .pending,
        optional: bool = false,
        error_message: ?[]const u8 = null,
    };

    pub const Status = enum {
        pending,
        active,
        completed,
        failed,
        skipped,

        pub fn isNavigable(self: Status) bool {
            return self == .completed or self == .failed or self == .active;
        }
    };

    pub const Orientation = enum {
        horizontal,
        vertical,
    };

    pub const Config = struct {
        orientation: Orientation = .horizontal,
        linear: bool = true,
        show_step_numbers: bool = true,
        allow_click_navigation: bool = true,
        initial_step: usize = 0,
    };

    pub fn init(allocator: std.mem.Allocator, props: ComponentProps, config: Config) !*Stepper {
        const stepper = try allocator.create(Stepper);
        stepper.* = Stepper{
            .component = try Component.init(allocator, "stepper", props),
            .steps = .{},
            .current_step = config.initial_step,
            .orientation = config.orientation,
            .linear = config.linear,
            .on_step_change = null,
            .show_step_numbers = config.show_step_numbers,
            .allow_click_navigation = config.allow_click_navigation,
        };
        return stepper;
    }

    pub fn deinit(self: *Stepper) void {
        self.steps.deinit(self.component.allocator);
        self.component.deinit();
        self.component.allocator.destroy(self);
    }

    /// Add a step
    pub fn addStep(self: *Stepper, label: []const u8) !void {
        try self.steps.append(self.component.allocator, .{
            .label = label,
        });
        // Set first step as active if this is the first step
        if (self.steps.items.len == 1) {
            self.steps.items[0].status = .active;
        }
    }

    /// Add a step with description
    pub fn addStepWithDescription(self: *Stepper, label: []const u8, description: []const u8) !void {
        try self.steps.append(self.component.allocator, .{
            .label = label,
            .description = description,
        });
        if (self.steps.items.len == 1) {
            self.steps.items[0].status = .active;
        }
    }

    /// Add a step with full configuration
    pub fn addStepWithConfig(self: *Stepper, step: Step) !void {
        try self.steps.append(self.component.allocator, step);
        if (self.steps.items.len == 1 and step.status == .pending) {
            self.steps.items[0].status = .active;
        }
    }

    /// Remove a step by index
    pub fn removeStep(self: *Stepper, index: usize) void {
        if (index < self.steps.items.len) {
            _ = self.steps.orderedRemove(index);
            // Adjust current step if needed
            if (self.current_step >= self.steps.items.len and self.steps.items.len > 0) {
                self.current_step = self.steps.items.len - 1;
            }
        }
    }

    /// Get step count
    pub fn getStepCount(self: *const Stepper) usize {
        return self.steps.items.len;
    }

    /// Get a step by index
    pub fn getStep(self: *const Stepper, index: usize) ?Step {
        if (index < self.steps.items.len) {
            return self.steps.items[index];
        }
        return null;
    }

    /// Get current step index
    pub fn getCurrentStep(self: *const Stepper) usize {
        return self.current_step;
    }

    /// Get current step data
    pub fn getCurrentStepData(self: *const Stepper) ?Step {
        return self.getStep(self.current_step);
    }

    /// Navigate to a specific step
    pub fn goToStep(self: *Stepper, index: usize) bool {
        if (index >= self.steps.items.len) return false;

        // In linear mode, can only go to completed steps or next step
        if (self.linear) {
            if (index > self.current_step + 1) return false;
            if (index < self.current_step) {
                // Can only go back to completed steps
                if (self.steps.items[index].status != .completed) return false;
            }
        }

        const old_step = self.current_step;

        // Update old step status
        if (self.steps.items[old_step].status == .active) {
            self.steps.items[old_step].status = .pending;
        }

        self.current_step = index;
        self.steps.items[index].status = .active;

        if (self.on_step_change) |callback| {
            callback(old_step, index);
        }

        return true;
    }

    /// Go to next step
    pub fn next(self: *Stepper) bool {
        if (self.current_step >= self.steps.items.len - 1) return false;

        // Mark current as completed
        self.steps.items[self.current_step].status = .completed;

        return self.goToStep(self.current_step + 1);
    }

    /// Go to previous step
    pub fn previous(self: *Stepper) bool {
        if (self.current_step == 0) return false;

        // In linear mode, mark current as pending
        self.steps.items[self.current_step].status = .pending;

        const old_step = self.current_step;
        self.current_step -= 1;
        self.steps.items[self.current_step].status = .active;

        if (self.on_step_change) |callback| {
            callback(old_step, self.current_step);
        }

        return true;
    }

    /// Complete the current step (marks as completed)
    pub fn completeCurrentStep(self: *Stepper) void {
        if (self.current_step < self.steps.items.len) {
            self.steps.items[self.current_step].status = .completed;
        }
    }

    /// Set step status
    pub fn setStepStatus(self: *Stepper, index: usize, status: Status) void {
        if (index < self.steps.items.len) {
            self.steps.items[index].status = status;
        }
    }

    /// Set step error
    pub fn setStepError(self: *Stepper, index: usize, error_message: ?[]const u8) void {
        if (index < self.steps.items.len) {
            self.steps.items[index].status = .failed;
            self.steps.items[index].error_message = error_message;
        }
    }

    /// Clear step error
    pub fn clearStepError(self: *Stepper, index: usize) void {
        if (index < self.steps.items.len) {
            if (self.steps.items[index].status == .failed) {
                self.steps.items[index].status = if (index == self.current_step) .active else .pending;
                self.steps.items[index].error_message = null;
            }
        }
    }

    /// Skip current step (if optional)
    pub fn skipCurrentStep(self: *Stepper) bool {
        if (self.current_step >= self.steps.items.len) return false;
        if (!self.steps.items[self.current_step].optional) return false;
        if (self.current_step >= self.steps.items.len - 1) return false;

        self.steps.items[self.current_step].status = .skipped;

        const old_step = self.current_step;
        self.current_step += 1;
        self.steps.items[self.current_step].status = .active;

        if (self.on_step_change) |callback| {
            callback(old_step, self.current_step);
        }

        return true;
    }

    /// Reset all steps to pending
    pub fn reset(self: *Stepper) void {
        for (self.steps.items) |*step| {
            step.status = .pending;
            step.error_message = null;
        }
        self.current_step = 0;
        if (self.steps.items.len > 0) {
            self.steps.items[0].status = .active;
        }
    }

    /// Check if at first step
    pub fn isFirstStep(self: *const Stepper) bool {
        return self.current_step == 0;
    }

    /// Check if at last step
    pub fn isLastStep(self: *const Stepper) bool {
        return self.current_step == self.steps.items.len - 1;
    }

    /// Check if all steps are completed
    pub fn isComplete(self: *const Stepper) bool {
        for (self.steps.items) |step| {
            if (step.status != .completed and step.status != .skipped) {
                return false;
            }
        }
        return true;
    }

    /// Get progress as percentage (0.0 - 1.0)
    pub fn getProgress(self: *const Stepper) f32 {
        if (self.steps.items.len == 0) return 0.0;

        var completed: usize = 0;
        for (self.steps.items) |step| {
            if (step.status == .completed or step.status == .skipped) {
                completed += 1;
            }
        }

        return @as(f32, @floatFromInt(completed)) / @as(f32, @floatFromInt(self.steps.items.len));
    }

    /// Get count of completed steps
    pub fn getCompletedCount(self: *const Stepper) usize {
        var count: usize = 0;
        for (self.steps.items) |step| {
            if (step.status == .completed) {
                count += 1;
            }
        }
        return count;
    }

    /// Set step label
    pub fn setStepLabel(self: *Stepper, index: usize, label: []const u8) void {
        if (index < self.steps.items.len) {
            self.steps.items[index].label = label;
        }
    }

    /// Set step description
    pub fn setStepDescription(self: *Stepper, index: usize, description: ?[]const u8) void {
        if (index < self.steps.items.len) {
            self.steps.items[index].description = description;
        }
    }

    /// Set step icon
    pub fn setStepIcon(self: *Stepper, index: usize, icon: ?[]const u8) void {
        if (index < self.steps.items.len) {
            self.steps.items[index].icon = icon;
        }
    }

    /// Set step as optional
    pub fn setStepOptional(self: *Stepper, index: usize, optional: bool) void {
        if (index < self.steps.items.len) {
            self.steps.items[index].optional = optional;
        }
    }

    /// Set orientation
    pub fn setOrientation(self: *Stepper, orientation: Orientation) void {
        self.orientation = orientation;
    }

    /// Set linear mode
    pub fn setLinear(self: *Stepper, linear: bool) void {
        self.linear = linear;
    }

    /// Set whether to show step numbers
    pub fn setShowStepNumbers(self: *Stepper, show: bool) void {
        self.show_step_numbers = show;
    }

    /// Set whether click navigation is allowed
    pub fn setAllowClickNavigation(self: *Stepper, allow: bool) void {
        self.allow_click_navigation = allow;
    }

    /// Set callback for step changes
    pub fn onStepChange(self: *Stepper, callback: *const fn (usize, usize) void) void {
        self.on_step_change = callback;
    }

    /// Handle click on a step (for click navigation)
    pub fn handleStepClick(self: *Stepper, index: usize) bool {
        if (!self.allow_click_navigation) return false;
        return self.goToStep(index);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "stepper creation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var stepper = try Stepper.init(allocator, props, .{});
    defer stepper.deinit();

    try std.testing.expectEqual(@as(usize, 0), stepper.getStepCount());
    try std.testing.expectEqual(Stepper.Orientation.horizontal, stepper.orientation);
    try std.testing.expect(stepper.linear);
}

test "stepper add steps" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var stepper = try Stepper.init(allocator, props, .{});
    defer stepper.deinit();

    try stepper.addStep("Step 1");
    try stepper.addStep("Step 2");
    try stepper.addStep("Step 3");

    try std.testing.expectEqual(@as(usize, 3), stepper.getStepCount());

    // First step should be active
    const step = stepper.getStep(0);
    try std.testing.expect(step != null);
    try std.testing.expectEqual(Stepper.Status.active, step.?.status);
}

test "stepper navigation" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var stepper = try Stepper.init(allocator, props, .{});
    defer stepper.deinit();

    try stepper.addStep("Step 1");
    try stepper.addStep("Step 2");
    try stepper.addStep("Step 3");

    try std.testing.expectEqual(@as(usize, 0), stepper.getCurrentStep());

    try std.testing.expect(stepper.next());
    try std.testing.expectEqual(@as(usize, 1), stepper.getCurrentStep());

    try std.testing.expect(stepper.previous());
    try std.testing.expectEqual(@as(usize, 0), stepper.getCurrentStep());
}

test "stepper linear mode" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var stepper = try Stepper.init(allocator, props, .{ .linear = true });
    defer stepper.deinit();

    try stepper.addStep("Step 1");
    try stepper.addStep("Step 2");
    try stepper.addStep("Step 3");

    // Should not be able to skip steps in linear mode
    try std.testing.expect(!stepper.goToStep(2));
    try std.testing.expectEqual(@as(usize, 0), stepper.getCurrentStep());

    // Can go to next step
    try std.testing.expect(stepper.next());
    try std.testing.expectEqual(@as(usize, 1), stepper.getCurrentStep());
}

test "stepper non-linear mode" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var stepper = try Stepper.init(allocator, props, .{ .linear = false });
    defer stepper.deinit();

    try stepper.addStep("Step 1");
    try stepper.addStep("Step 2");
    try stepper.addStep("Step 3");

    // Can jump to any step in non-linear mode
    try std.testing.expect(stepper.goToStep(2));
    try std.testing.expectEqual(@as(usize, 2), stepper.getCurrentStep());
}

test "stepper progress" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var stepper = try Stepper.init(allocator, props, .{});
    defer stepper.deinit();

    try stepper.addStep("Step 1");
    try stepper.addStep("Step 2");
    try stepper.addStep("Step 3");
    try stepper.addStep("Step 4");

    try std.testing.expectApproxEqAbs(@as(f32, 0.0), stepper.getProgress(), 0.01);

    _ = stepper.next();
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), stepper.getProgress(), 0.01);

    _ = stepper.next();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), stepper.getProgress(), 0.01);
}

test "stepper completion" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var stepper = try Stepper.init(allocator, props, .{});
    defer stepper.deinit();

    try stepper.addStep("Step 1");
    try stepper.addStep("Step 2");

    try std.testing.expect(!stepper.isComplete());

    _ = stepper.next();
    stepper.completeCurrentStep();

    try std.testing.expect(stepper.isComplete());
}

test "stepper error handling" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var stepper = try Stepper.init(allocator, props, .{});
    defer stepper.deinit();

    try stepper.addStep("Step 1");
    try stepper.addStep("Step 2");

    stepper.setStepError(0, "Validation failed");

    const step = stepper.getStep(0);
    try std.testing.expect(step != null);
    try std.testing.expectEqual(Stepper.Status.failed, step.?.status);
    try std.testing.expectEqualStrings("Validation failed", step.?.error_message.?);

    stepper.clearStepError(0);
    const cleared = stepper.getStep(0);
    try std.testing.expectEqual(Stepper.Status.active, cleared.?.status);
}

test "stepper skip optional" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var stepper = try Stepper.init(allocator, props, .{});
    defer stepper.deinit();

    try stepper.addStep("Required");
    try stepper.addStepWithConfig(.{
        .label = "Optional",
        .optional = true,
    });
    try stepper.addStep("Final");

    _ = stepper.next();
    try std.testing.expect(stepper.skipCurrentStep());
    try std.testing.expectEqual(@as(usize, 2), stepper.getCurrentStep());

    const skipped = stepper.getStep(1);
    try std.testing.expectEqual(Stepper.Status.skipped, skipped.?.status);
}

test "stepper reset" {
    const allocator = std.testing.allocator;
    const props = ComponentProps{};
    var stepper = try Stepper.init(allocator, props, .{});
    defer stepper.deinit();

    try stepper.addStep("Step 1");
    try stepper.addStep("Step 2");
    try stepper.addStep("Step 3");

    _ = stepper.next();
    _ = stepper.next();

    stepper.reset();

    try std.testing.expectEqual(@as(usize, 0), stepper.getCurrentStep());
    try std.testing.expectEqual(Stepper.Status.active, stepper.getStep(0).?.status);
    try std.testing.expectEqual(Stepper.Status.pending, stepper.getStep(1).?.status);
}
