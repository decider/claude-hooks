# Anchor Framework Best Practices

## Program Structure
- Organize instructions in logical groups
- Keep account validation separate from business logic
- Use custom errors instead of generic messages

## Account Validation
- Always validate account ownership
- Check account discriminators
- Verify PDA derivations match expected seeds
- Use `#[account()]` constraints effectively

## Security Patterns
### Required Validations
```rust
#[account(
    mut,
    seeds = [b"vault", user.key().as_ref()],
    bump,
    has_one = authority @ CustomError::InvalidAuthority,
)]
pub vault: Account<'info, Vault>,
```

### Signer Checks
- Always require appropriate signers
- Use `Signer` type for authority accounts
- Implement multi-sig when handling valuable assets

## Error Handling
```rust
#[error_code]
pub enum CustomError {
    #[msg("Invalid authority for this operation")]
    InvalidAuthority,
    #[msg("Insufficient funds in vault")]
    InsufficientFunds,
    #[msg("Operation would cause overflow")]
    Overflow,
}
```

## State Management
- Initialize accounts with proper space allocation
- Use zero-copy for large data structures
- Implement proper account closing to reclaim rent

## Common Anti-patterns to Avoid
- Using `unwrap()` in production code
- Skipping overflow checks in arithmetic
- Not validating account ownership
- Forgetting to check PDA bumps
- Using mutable references when not needed