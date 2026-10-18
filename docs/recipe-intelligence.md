# Recipe chat and suggestions

Recipe chat and review summaries use the on-device Apple Intelligence model by default. The Private Cloud Compute implementation remains available behind a LaunchDarkly flag for approved builds on iOS 27 and later. Ingredient emoji generation stays on device.

Cloud requests fall back to an available on-device model when the cloud model is unavailable, its daily quota is exhausted, or a request fails. Cancellation and model safety refusals do not trigger another request. The chat displays the selected route, including a cloud failure or daily-limit fallback.

## Developer account setup

The main app does not request `com.apple.developer.private-cloud-compute`. Cloud routing is controlled by the LaunchDarkly Boolean flag `recipe-private-cloud-compute-enabled`, which defaults to `false`. The existing `recipe_chat_enabled` flag separately controls whether chat is shown. Chat and review summaries share the cloud routing flag; ingredient emojis stay local.

Flag changes update the recipe page without a restart. Each generation uses the routing preference at the start of the request; changing the flag affects subsequent requests.

After Apple grants access:

1. Add `com.apple.developer.private-cloud-compute` as a Boolean set to `true` in `sporkcast/sporkcast.entitlements` and regenerate provisioning profiles that include it.
2. Ship that signed build, then enable `recipe-private-cloud-compute-enabled` in LaunchDarkly for its app version. Keep the flag off for older builds without the entitlement.
3. Test on an eligible physical device. Cloud becomes the preferred model with on-device fallback.

The LaunchDarkly flag cannot grant the entitlement. Enabling it on a physical-device build without the signed entitlement can terminate the process inside the framework. See [Apple's Private Cloud Compute access requirements](https://developer.apple.com/private-cloud-compute/).

Apple documents testing via TestFlight or ad hoc distribution. Simulator builds always use the local route: cloud availability can report success there even when an unsigned process lacks the managed entitlement, causing a framework fatal error. A simulator build verifies API compatibility and layout, but does not establish that a signed app can make cloud requests.

## Verification

- Run `RecipeTests`, including `RecipeChatTests`, on an iOS simulator.
- With the cloud opt-in enabled and entitlement granted, on an eligible device ask a question with cloud access available and verify the Private Cloud Compute label.
- Disable connectivity and verify a failed cloud request retries locally when the on-device model is ready.
- Use the scheme's simulated Foundation Models availability options to verify approaching/exhausted cloud quota behavior.
- Stop a pending response, then start a new conversation; an old response must not reappear.
- Check starter cards and the composer at accessibility text sizes and in dark mode.

Recipe context preserves section and step order. The cloud route receives more recipe text and conversation history; the local route uses a smaller budget. Truncated recipe context is explicitly marked incomplete in the prompt. Questions have a visible 2,000-character limit rather than being silently truncated. Chat history remains in memory for the lifetime of the recipe view model.
