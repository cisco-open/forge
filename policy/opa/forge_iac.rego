# ForgeMT policy-as-code — tenant-isolation invariants (register P0-7, P1-8, P1-10).
#
# These encode two invariants that protect the STS isolation boundary and the
# tenant log buckets. They evaluate IAM/S3 policy JSON documents (input = a
# single policy document with a Statement list).
#
# Run as a gate over rendered policy JSON, e.g.:
#   conftest test path/to/policy.json --policy policy/opa
# The embedded `test_*` rules let `conftest verify` validate the policy LOGIC in
# CI with no AWS and no tofu plan — so this gate is deterministic.
#
# WHY a gate: Phase 1 found no wildcard trust today, but nothing stops one being
# added. This fails CI the moment a tenant trust policy goes wildcard or a
# tenant bucket policy is left open.

package main

# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #
statements[s] {
	s := input.Statement[_]
}

# Normalise Action to a set whether it is a string or a list.
action_set(stmt) = actions {
	is_string(stmt.Action)
	actions := {stmt.Action}
}

action_set(stmt) = actions {
	is_array(stmt.Action)
	actions := {a | a := stmt.Action[_]}
}

allows_assume_role(stmt) {
	stmt.Effect == "Allow"
	action_set(stmt)["sts:AssumeRole"]
}

allows_assume_role(stmt) {
	stmt.Effect == "Allow"
	action_set(stmt)["sts:*"]
}

# Wildcard principal in any of the shapes IAM accepts.
principal_is_wildcard(stmt) {
	stmt.Principal == "*"
}

principal_is_wildcard(stmt) {
	stmt.Principal.AWS == "*"
}

principal_is_wildcard(stmt) {
	stmt.Principal.AWS[_] == "*"
}

has_condition(stmt) {
	stmt.Condition
}

# --------------------------------------------------------------------------- #
# Rule 1: no wildcard principal may assume a role (STS isolation boundary).
# --------------------------------------------------------------------------- #
deny[msg] {
	some i
	stmt := input.Statement[i]
	allows_assume_role(stmt)
	principal_is_wildcard(stmt)
	msg := sprintf(
		"P0-7: statement %d allows sts:AssumeRole from a wildcard principal — tenant trust must name an explicit principal",
		[i],
	)
}

# --------------------------------------------------------------------------- #
# Rule 2: a tenant bucket policy must not grant a wildcard principal without a
# scoping Condition (unscoped tenant bucket = cross-tenant read/write risk).
# --------------------------------------------------------------------------- #
deny[msg] {
	some i
	stmt := input.Statement[i]
	stmt.Effect == "Allow"
	principal_is_wildcard(stmt)
	not has_condition(stmt)
	startswith(action_member(stmt), "s3:")
	msg := sprintf(
		"P1-8: statement %d grants S3 access to a wildcard principal with no Condition — tenant bucket policy must be scoped",
		[i],
	)
}

# Any one action, used only to detect the s3: namespace above.
action_member(stmt) = a {
	a := action_set(stmt)[_]
}

# --------------------------------------------------------------------------- #
# Self-tests (run by `conftest verify`)
# --------------------------------------------------------------------------- #
test_denies_wildcard_assume_role {
	count(deny) == 1 with input as {
		"Version": "2012-10-17",
		"Statement": [{
			"Effect": "Allow",
			"Action": "sts:AssumeRole",
			"Principal": {"AWS": "*"},
		}],
	}
}

test_allows_scoped_assume_role {
	count(deny) == 0 with input as {
		"Version": "2012-10-17",
		"Statement": [{
			"Effect": "Allow",
			"Action": ["sts:AssumeRole", "sts:TagSession"],
			"Principal": {"AWS": "arn:aws:iam::111111111111:role/runner"},
		}],
	}
}

test_denies_unscoped_bucket_policy {
	count(deny) == 1 with input as {
		"Version": "2012-10-17",
		"Statement": [{
			"Effect": "Allow",
			"Action": ["s3:GetObject"],
			"Principal": "*",
		}],
	}
}

test_allows_bucket_policy_with_condition {
	count(deny) == 0 with input as {
		"Version": "2012-10-17",
		"Statement": [{
			"Effect": "Allow",
			"Action": ["s3:GetObject"],
			"Principal": "*",
			"Condition": {"StringEquals": {"aws:PrincipalAccount": "123456789012"}},
		}],
	}
}

test_denies_wildcard_star_action_assume {
	count(deny) == 1 with input as {
		"Version": "2012-10-17",
		"Statement": [{
			"Effect": "Allow",
			"Action": "sts:*",
			"Principal": {"AWS": ["*"]},
		}],
	}
}
