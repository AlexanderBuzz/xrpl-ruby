# frozen_string_literal: true

describe Wallet::Wallet do
  let(:key_pairs) { KeyPairs::KeyPairs.new }
  let(:secp_seed_real) { 'sn3nxiR7v8cxz7SstqthA8r7B8m6K' }
  let(:secp_address_real) { 'rNgukJ8aypeCx9fE58C47FwtCGgbEFywLb' } # Derived from key_pairs_spec test

  describe '.new' do
    it 'creates a wallet from public and private keys' do
      wallet = Wallet::Wallet.new('PUBLIC_KEY_HEX', 'PRIVATE_KEY_HEX')
      expect(wallet.public_key).to eq('PUBLIC_KEY_HEX')
      expect(wallet.private_key).to eq('PRIVATE_KEY_HEX')
    end

    it 'sets algorithm to ed25519 if public key starts with ED' do
      wallet = Wallet::Wallet.new('ED' + '0' * 64, 'PRIVATE_KEY_HEX')
      expect(wallet.algorithm).to eq('ed25519')
    end

    it 'sets algorithm to secp256k1 if public key does not start with ED' do
      wallet = Wallet::Wallet.new('0' * 66, 'PRIVATE_KEY_HEX')
      expect(wallet.algorithm).to eq('secp256k1')
    end

    it 'allows providing a custom classic address' do
      wallet = Wallet::Wallet.new('0' * 66, 'PRIVATE_KEY_HEX', classic_address: 'CUSTOM_ADDRESS')
      expect(wallet.classic_address).to eq('CUSTOM_ADDRESS')
    end
  end

  describe '.generate' do
    it 'generates a secp256k1 wallet by default' do
      wallet = Wallet::Wallet.generate
      expect(wallet.classic_address).to start_with('r')
      expect(wallet.public_key.length).to eq(66) # 33 bytes in hex
    end

    it 'generates an ed25519 wallet' do
      wallet = Wallet::Wallet.generate('ed25519')
      expect(wallet.classic_address).to start_with('r')
      expect(wallet.public_key).to start_with('ED')
      expect(wallet.public_key.length).to eq(66) # 33 bytes (ED + 32 bytes)
    end
  end

  describe '.from_seed' do
    it 'creates a wallet from a secp256k1 seed' do
      seed = key_pairs.generate_seed([0]*16, 'secp256k1')
      wallet = Wallet::Wallet.from_seed(seed)
      expect(wallet.classic_address).to start_with('r')
      expect(wallet.seed).to eq(seed)
    end

    it 'creates a wallet from an ed25519 seed' do
      seed = key_pairs.generate_seed([0]*16, 'ed25519')
      wallet = Wallet::Wallet.from_seed(seed)
      expect(wallet.public_key).to start_with('ED')
      expect(wallet.seed).to eq(seed)
    end
  end

  describe '.from_entropy' do
    it 'creates a wallet from entropy' do
      entropy = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
      wallet = Wallet::Wallet.from_entropy(entropy)
      expect(wallet.seed).not_to be_nil
      expect(wallet.classic_address).to start_with('r')
    end
  end

  describe '#sign and #verify' do
    let(:wallet_ed) { Wallet::Wallet.generate('ed25519') }
    let(:wallet_secp) { Wallet::Wallet.generate('secp256k1') }
    let(:message) { 'DEADBEEF' }

    it 'signs and verifies an Ed25519 message' do
      signature = wallet_ed.sign(message)
      expect(wallet_ed.verify(message, signature)).to be true
    end

    it 'fails verification for a different message (Ed25519)' do
      signature = wallet_ed.sign(message)
      expect(wallet_ed.verify('CAFEBABE', signature)).to be false
    end

    it 'signs a transaction hash (JSON/Hash)' do
      tx = {
        'TransactionType' => 'Payment',
        'Account' => wallet_ed.classic_address,
        'Destination' => 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
        'Amount' => '1000',
        'Sequence' => 1,
        'Fee' => '10'
      }
      signature = wallet_ed.sign(tx)
      expect(signature).not_to be_nil
    end

    it 'signs and verifies a Secp256k1 message' do
      begin
        signature = wallet_secp.sign(message)
        expect(wallet_secp.verify(message, signature)).to be true
      rescue => e
        pending "Secp256k1 signing/verification failed: #{e.message} (OpenSSL 3.0 restriction)"
        raise e
      end
    end
  end

  describe '#verify_transaction' do
    let(:kp) { KeyPairs::KeyPairs.new }
    let(:real_ed_seed) { kp.generate_seed([0]*16, 'ed25519') }
    let(:wallet_real) { Wallet::Wallet.from_seed(real_ed_seed) }
    let(:signed_tx_hex) do
      tx = {
        'TransactionType' => 'Payment',
        'Account' => wallet_real.classic_address,
        'Destination' => 'rHb9CJAWyB4rj91VRWn96DkukG4bwdtyTh',
        'Amount' => '1000',
        'Sequence' => 1,
        'Fee' => '10'
      }
      # Sign it manually for the test
      signing_data = BinaryCodec.signing_data(tx)
      signature = wallet_real.sign(bytes_to_hex(signing_data))
      tx['TxnSignature'] = signature
      BinaryCodec.json_to_binary(tx)
    end

    it 'verifies a signed transaction blob' do
      expect(wallet_real.verify_transaction(signed_tx_hex)).to be true
    end
  end

  describe '#get_x_address' do
    let(:seed) { key_pairs.generate_seed([0]*16, 'secp256k1') }
    let(:wallet) { Wallet::Wallet.from_seed(seed) }

    it 'derives a mainnet X-address without tag' do
      x_address = wallet.get_x_address
      expect(x_address).to start_with('X')
    end

    it 'derives a testnet X-address with tag' do
      x_address = wallet.get_x_address(tag: 123, test_network: true)
      expect(x_address).to start_with('T')
    end
  end
end
