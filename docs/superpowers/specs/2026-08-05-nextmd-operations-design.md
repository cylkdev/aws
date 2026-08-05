# Design: NEXT.md operations — the operations deployd needs

Date: 2026-08-05
Status: approved

## Goal

Implement every operation listed in `NEXT.md`, including the two marked
optional (`AwsSdk.SSM.list_command_invocations`, `AwsSdk.S3.delete_objects`).
All are functions added to existing service modules — no new modules. Commit
`e44e734` (launch-template reads) is the pattern to copy.

## Cross-cutting conventions (every operation)

- Public function with a `sandbox?/1` branch delegating to the service's
  `Sandbox` module; otherwise a `do_*` private impl: params →
  `with {:ok, op} <- build_operation(...), {:ok, %{body: body}} <- Client.request(op)`
  → parse (the explicit pipeline from the Client.request refactor).
- Response parsed to the **full documented AWS shape** per the response
  fidelity rules in `CLAUDE.md`: nesting preserved, member names preserved
  (`snake_case` of the AWS name), `*Set/item` lists preserved, nothing
  dropped (including pagination tokens), envelope dropped. Leaf coercion
  only: integers and booleans. Timestamps stay ISO8601 strings, matching
  the existing parsers (`e44e734` keeps `createTime` as a string; AutoScaling
  and IAM do the same).
- `defdelegate sandbox_<op>_response` in the service module; the
  `<op>_response` / `set_<op>_responses` pair in the service's `Sandbox`
  module. Registry key is the first positional argument; when the first
  argument is a list or the operation has no required input, the key is
  `"*"` (matches the existing `get_parameters` precedent).
- XML selectors anchored to their result element; nested singletons use an
  optional (`o`) anchor so absent structures parse to `nil`.
- Per operation: one conformance test parsing a realistic fixture in
  `test/aws_sdk/conformance_test.exs` (fidelity is enforced there), and
  sandbox tests in the service's sandbox test file.

## AwsSdk.SSM (JSON 1.1)

| Function | Signature | Notes |
|---|---|---|
| `send_command` | `send_command(instance_ids, document_name, opts \\ [])` | `opts`: `:parameters`, `:comment`, `:timeout_seconds`, output S3/CloudWatch options, etc. Returns the full `Command` structure (deployd reads `command_id`). Sandbox key `"*"`. |
| `send_command_by_targets` | `send_command_by_targets(targets, document_name, opts \\ [])` | The one-of partner (AWS: `InstanceIds` xor `Targets`), per the `describe_rules`/`describe_rules_by_arns` precedent. Sandbox key `"*"`. |
| `get_command_invocation` | `get_command_invocation(command_id, instance_id, opts \\ [])` | Both AWS-required. Full shape: `status`, `status_details`, `standard_output_content`, `standard_error_content`, `response_code`, plugin/document fields, output URLs. Sandbox keys off `command_id`. |
| `list_command_invocations` | `list_command_invocations(opts \\ [])` | All inputs optional (`:command_id`, `:instance_id`, `:details`, `:filters`, `:max_results`, `:next_token`). Sandbox key `"*"`. |

## AwsSdk.EC2 (Query/XML; `put_member_list/3` + `put_filters/2`, inline SweetXml parsing)

Required-by-AWS inputs are positional; describes are opts-only like every
existing EC2 describe.

| Function | Signature | Notes |
|---|---|---|
| `terminate_instances` | `(instance_ids, opts)` | Parses `instancesSet` → `[%{instance_id, current_state, previous_state}]` with state `code` as integer. |
| `get_console_output` | `(instance_id, opts)` | `:latest` in opts. `output` Base64-decoded (per NEXT.md); `timestamp` kept as the ISO8601 string. |
| `describe_network_acls` | `(opts)` | Full shape: `entrySet` (icmp type/code, port range), `associationSet`, `tagSet`, `is_default`, `vpc_id`, `owner_id`, `next_token`. |
| `describe_route_tables` | `(opts)` | `routeSet`, `associationSet` (incl. `associationState`), `propagatingVgwSet`, `tagSet`, `next_token`. |
| `describe_key_pairs` | `(opts)` | `keySet` with fingerprint, type, create time, tags. |
| `delete_key_pair` | `(key_name, opts)` | Returns `return`/`key_pair_id` per the documented response. |
| `describe_security_group_rules` | `(opts)` | Rule-granular read: `securityGroupRuleSet` with referenced group info, `next_token`. |
| `describe_snapshots` | `(opts)` | `:owner_ids`, `:snapshot_ids`, `:filters`, pagination. Full snapshot shape, `start_time` as ISO8601 string. |
| `describe_network_interfaces` | `(opts)` | `attachment`, `association`, `groupSet`, `privateIpAddressesSet`, `tagSet`, `next_token`. |
| `describe_instance_status` | `(opts)` | `:instance_ids`, `:include_all_instances`. `systemStatus`/`instanceStatus` with `details` lists, `eventsSet`. |
| `describe_iam_instance_profile_associations` | `(opts)` | Association id, instance id, `iamInstanceProfile`, state, timestamp. |
| `create_network_insights_path` | `(source, destination, protocol, opts)` | `destination` positional (NEXT.md specifies it; deployd always passes it) even though AWS marks it optional. `:destination_port` in opts. Auto-generated `ClientToken` UUID. Returns the full `NetworkInsightsPath`. |
| `start_network_insights_analysis` | `(path_id, opts)` | Auto `ClientToken`. Returns the full `NetworkInsightsAnalysis` (initial state). |
| `describe_network_insights_analyses` | `(opts)` | `:analysis_ids`, `:path_id`, filters, pagination. Full documented shape including `status`, `network_path_found`, `explanations`, `forward_path_components`/`return_path_components` — parsed per the documented members, not truncated. Deployd polls `status == "succeeded"`. |
| `delete_network_insights_path` | `(path_id, opts)` | Returns the deleted path id. |

## AwsSdk.AutoScaling (Query; `flatten_query/1`, extracted `parse_*`)

| Function | Signature | Notes |
|---|---|---|
| `describe_scaling_activities` | `(auto_scaling_group_name, opts)` | Mirrors `describe_instance_refreshes` exactly. `:max_records`, pagination in opts. Full `Activity` shape: `status_code`, `status_message`, `cause`, `description`, `details`, `progress`, `start_time`/`end_time` as ISO8601 strings, `next_token`. |

## AwsSdk.ElasticLoadBalancingV2 (Query; `flatten_query/1`)

| Function | Signature | Notes |
|---|---|---|
| `modify_listener` | `(listener_arn, default_actions, opts)` | Mirrors `modify_rule(rule_arn, actions, opts)` including the action encoding (the fixed-response 503 reset is the deployd use). Parses the returned `Listeners` list in the `parse_describe_listeners` shape. |

## AwsSdk.IAM (Query/XML; global, pinned to us-east-1)

| Function | Signature | Notes |
|---|---|---|
| `get_instance_profile` | `(instance_profile_name, opts)` | Reuses the existing `parse_role` for the nested `Roles` member. `create_date` as ISO8601 string. |

## AwsSdk.S3 (REST/XML)

| Function | Signature | Notes |
|---|---|---|
| `delete_objects` | `(bucket, objects, opts)` | POST `?delete` with XML body from a new `S3.XMLBuilder.build_delete/1`; `Content-MD5` header (S3 requires it for this operation). `objects`: list of keys (binaries) or `%{key: _, version_id: _}` maps. `:quiet` in opts. Parses `DeleteResult` into `deleted: [...]` and `error: [...]` lists with anchored selectors (S3 can return `<Error>` on a 200). |

## Testing

- Conformance: one fixture-backed parse case per new parser in
  `test/aws_sdk/conformance_test.exs` — this is where response fidelity is
  enforced.
- Sandbox: per-operation tests asserting delegation, keying, and
  `AwsSdk.Counter` behavior, in each service's sandbox test file.
- `mix compile` (warnings-as-errors), `mix test`, `mix format` clean at
  every commit.

## Commit plan

One commit per coherent feature unit, each fully tested (lib + sandbox +
conformance + sandbox tests together), matching `e44e734`:

1. SSM `send_command` + `send_command_by_targets`
2. SSM `get_command_invocation`
3. SSM `list_command_invocations`
4. EC2 `terminate_instances`
5. EC2 `get_console_output`
6. EC2 `describe_network_acls`
7. EC2 `describe_route_tables`
8. EC2 `describe_key_pairs` + `delete_key_pair`
9. EC2 `describe_security_group_rules`
10. EC2 `describe_snapshots`
11. EC2 `describe_network_interfaces`
12. EC2 `describe_instance_status`
13. EC2 `describe_iam_instance_profile_associations`
14. EC2 Reachability Analyzer quartet (`create_network_insights_path`,
    `start_network_insights_analysis`,
    `describe_network_insights_analyses`, `delete_network_insights_path`)
15. AutoScaling `describe_scaling_activities`
16. ElasticLoadBalancingV2 `modify_listener`
17. IAM `get_instance_profile`
18. S3 `delete_objects`

`NEXT.md` is deleted in the final commit once everything on it is
implemented.
