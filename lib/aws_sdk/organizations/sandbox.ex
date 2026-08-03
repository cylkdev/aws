if Code.ensure_loaded?(SandboxRegistry) do
  defmodule AwsSdk.Organizations.Sandbox do
    @moduledoc false

    @registry :aws_organizations_sandbox

    def start_link, do: AwsSdk.Sandbox.start_link(@registry)

    @spec disable_aws_organizations_sandbox(map) :: :ok
    def disable_aws_organizations_sandbox(_context),
      do: AwsSdk.Sandbox.disable(@registry, __MODULE__)

    @spec sandbox_disabled? :: boolean
    def sandbox_disabled?, do: AwsSdk.Sandbox.disabled?(@registry, __MODULE__)

    def create_organization_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :create_organization, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_create_organization_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_organization,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_organization_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_organization, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_delete_organization_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_organization,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_organization_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_organization, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_describe_organization_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_organization,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_organizational_unit_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :create_organizational_unit, name, examples)

      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_organizational_unit_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_organizational_unit,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def delete_organizational_unit_response(ou_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:ou_id])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :delete_organizational_unit, ou_id, examples)

      AwsSdk.Sandbox.apply_func(func, [ou_id, opts], examples)
    end

    def set_delete_organizational_unit_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :delete_organizational_unit,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_organizational_units_for_parent_response(parent_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:parent_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :list_organizational_units_for_parent,
          parent_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [parent_id, opts], examples)
    end

    def set_list_organizational_units_for_parent_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_organizational_units_for_parent,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def create_account_response(name, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:name])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :create_account, name, examples)
      AwsSdk.Sandbox.apply_func(func, [name, opts], examples)
    end

    def set_create_account_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :create_account,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_create_account_status_response(request_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:request_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_create_account_status,
          request_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [request_id, opts], examples)
    end

    def set_describe_create_account_status_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_create_account_status,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def move_account_response(account_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:account_id])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :move_account, account_id, examples)
      AwsSdk.Sandbox.apply_func(func, [account_id, opts], examples)
    end

    def set_move_account_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :move_account,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def close_account_response(account_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:account_id])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :close_account, account_id, examples)
      AwsSdk.Sandbox.apply_func(func, [account_id, opts], examples)
    end

    def set_close_account_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :close_account,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_accounts_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_accounts, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_accounts_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_accounts,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_roots_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_roots, "*", examples)
      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_roots_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_roots,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def register_delegated_administrator_response(account_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:account_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :register_delegated_administrator,
          account_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [account_id, opts], examples)
    end

    def set_register_delegated_administrator_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :register_delegated_administrator,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def enable_aws_service_access_response(service_principal, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:service_principal])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :enable_aws_service_access,
          service_principal,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [service_principal, opts], examples)
    end

    def set_enable_aws_service_access_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :enable_aws_service_access,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_delegated_administrators_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_delegated_administrators, "*", examples)

      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_delegated_administrators_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_delegated_administrators,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_aws_service_access_for_organization_response(opts) do
      examples = AwsSdk.Sandbox.doc_examples([])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :list_aws_service_access_for_organization,
          "*",
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [opts], examples)
    end

    def set_list_aws_service_access_for_organization_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_aws_service_access_for_organization,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_parents_response(child_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:child_id])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_parents, child_id, examples)
      AwsSdk.Sandbox.apply_func(func, [child_id, opts], examples)
    end

    def set_list_parents_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_parents,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_account_response(account_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:account_id])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :describe_account, account_id, examples)
      AwsSdk.Sandbox.apply_func(func, [account_id, opts], examples)
    end

    def set_describe_account_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_account,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def describe_organizational_unit_response(ou_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:ou_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :describe_organizational_unit,
          ou_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [ou_id, opts], examples)
    end

    def set_describe_organizational_unit_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :describe_organizational_unit,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def update_organizational_unit_response(ou_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:ou_id])

      func =
        AwsSdk.Sandbox.find!(@registry, __MODULE__, :update_organizational_unit, ou_id, examples)

      AwsSdk.Sandbox.apply_func(func, [ou_id, opts], examples)
    end

    def set_update_organizational_unit_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :update_organizational_unit,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def disable_aws_service_access_response(service_principal, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:service_principal])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :disable_aws_service_access,
          service_principal,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [service_principal, opts], examples)
    end

    def set_disable_aws_service_access_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :disable_aws_service_access,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def deregister_delegated_administrator_response(account_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:account_id])

      func =
        AwsSdk.Sandbox.find!(
          @registry,
          __MODULE__,
          :deregister_delegated_administrator,
          account_id,
          examples
        )

      AwsSdk.Sandbox.apply_func(func, [account_id, opts], examples)
    end

    def set_deregister_delegated_administrator_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :deregister_delegated_administrator,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end

    def list_children_response(parent_id, opts) do
      examples = AwsSdk.Sandbox.doc_examples([:parent_id])
      func = AwsSdk.Sandbox.find!(@registry, __MODULE__, :list_children, parent_id, examples)
      AwsSdk.Sandbox.apply_func(func, [parent_id, opts], examples)
    end

    def set_list_children_responses(tuples) do
      AwsSdk.Sandbox.set_responses(
        @registry,
        __MODULE__,
        :list_children,
        AwsSdk.Sandbox.normalize_no_key(tuples)
      )
    end
  end
end
