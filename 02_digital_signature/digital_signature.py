import time
import hashlib

from Crypto.PublicKey import RSA
from Crypto.Hash import SHA256
from Crypto.Signature import pkcs1_15

# 1. 生成 RSA 密钥对（2048 位）
key = RSA.generate(2048)  # 私钥和公钥都含在 key 对象中 :contentReference[oaicite:1]{index=1}
private_key = key
public_key = key.publickey()

print(f"private key：{private_key}")
print(f"public key：{public_key}")
# 2. PoW
def proof_of_work(nickname: str, difficulty: int = 4):
    prefix = '0' * difficulty
    nonce = 0
    start = time.time()
    while True:
        message = f"{nickname}{nonce}".encode()
        hash_hex = hashlib.sha256(message).hexdigest()
        if hash_hex.startswith(prefix):
            elapsed = time.time() - start
            return nonce, hash_hex, elapsed
        nonce += 1

nickname = "NULL"
nonce, pow_hash, elapsed = proof_of_work(nickname, difficulty=4)
print(f"PoW 完成：nonce={nonce}, hash={pow_hash}, 耗时={elapsed:.3f}s") 

# 3. 用私钥对 “昵称+nonce” 的原始数据进行签名
data = f"{nickname}{nonce}".encode()
h = SHA256.new(data)
signature = pkcs1_15.new(private_key).sign(h)  # 生成签名

print(f"签名（hex）：{signature.hex()}")

# 4. 使用公钥验证签名
try:
    #pkcs1_15.new(public_key).verify(h, signature)
    pkcs1_15.new(public_key).verify(h, signature)
    print("verify successful")
except (ValueError, TypeError):
    print("verify failed")

