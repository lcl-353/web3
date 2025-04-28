import hashlib
import time

def proof_of_work(data, difficulty=4):
    nonce = 0
    prefix = '0' * difficulty
    
    start_time = time.time()  # 开始计时
    
    while True:
        text = data + str(nonce)
        hash_result = hashlib.sha256(text.encode()).hexdigest()
        if hash_result.startswith(prefix):
            end_time = time.time()  # 找到符合的，停止计时
            elapsed_time = end_time - start_time
            return nonce, hash_result, elapsed_time
        nonce += 1

if __name__ == "__main__":
    data = "NULL"
    difficulty = 5  # 前4位0
    nonce, hash_result, elapsed_time = proof_of_work(data, difficulty)
    
    print(f"找到符合要求的 Nonce：{nonce}")
    print(f"对应的哈希值：{hash_result}")
    print(f"耗时：{elapsed_time:.4f} 秒")

