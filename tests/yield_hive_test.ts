import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensure that user can create a pool",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('yield-hive', 'create-pool', [
        types.uint(1),
        types.principal(deployer.address),
        types.uint(100)
      ], deployer.address),
      // Should fail for non-owner
      Tx.contractCall('yield-hive', 'create-pool', [
        types.uint(2),
        types.principal(deployer.address),
        types.uint(100)
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectOk();
    block.receipts[1].result.expectErr(types.uint(100)); // err-owner-only
  },
});

Clarinet.test({
  name: "Test staking workflow",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      // Create pool
      Tx.contractCall('yield-hive', 'create-pool', [
        types.uint(1),
        types.principal(deployer.address),
        types.uint(100)
      ], deployer.address),
      // Stake tokens
      Tx.contractCall('yield-hive', 'stake', [
        types.uint(1),
        types.uint(1000)
      ], wallet1.address),
    ]);
    
    block.receipts[0].result.expectOk();
    block.receipts[1].result.expectOk();
    
    // Check position
    let positionBlock = chain.mineBlock([
      Tx.contractCall('yield-hive', 'get-position', [
        types.principal(wallet1.address),
        types.uint(1)
      ], wallet1.address)
    ]);
    
    const position = positionBlock.receipts[0].result.expectSome();
    assertEquals(position.amount, types.uint(1000));
  },
});

Clarinet.test({
  name: "Test rewards calculation and claiming",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      // Create pool
      Tx.contractCall('yield-hive', 'create-pool', [
        types.uint(1),
        types.principal(deployer.address),
        types.uint(100)
      ], deployer.address),
      // Stake tokens
      Tx.contractCall('yield-hive', 'stake', [
        types.uint(1),
        types.uint(1000)
      ], wallet1.address),
    ]);
    
    // Mine some blocks to accumulate rewards
    chain.mineEmptyBlock(10);
    
    // Claim rewards
    let claimBlock = chain.mineBlock([
      Tx.contractCall('yield-hive', 'claim-rewards', [
        types.uint(1)
      ], wallet1.address)
    ]);
    
    claimBlock.receipts[0].result.expectOk();
  },
});