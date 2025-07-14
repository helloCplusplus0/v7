"""
Natural Language Processing Algorithms

Contains Python implementations of NLP algorithms.
Note: This is a basic implementation for demonstration.
Production use should consider more sophisticated libraries.
"""

import re
import math
from typing import Dict, List, Any
from collections import Counter
import warnings

class NLPAlgorithms:
    """自然语言处理算法实现"""
    
    def __init__(self):
        self.available = True  # 基础实现，不需要额外依赖
    
    def sentiment_analysis(self, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """情感分析（简化版本）"""
        # 注意：这里data是数值列表，但NLP需要文本
        # 实际使用中应该传入文本数据
        text = params.get("text", "")
        if not text:
            raise ValueError("NLP sentiment analysis requires 'text' parameter")
        
        # 简单的情感词典方法
        positive_words = {
            'good', 'great', 'excellent', 'amazing', 'wonderful', 'fantastic',
            'awesome', 'perfect', 'love', 'like', 'happy', 'joy', 'pleased',
            'satisfied', 'brilliant', 'outstanding', 'superb'
        }
        
        negative_words = {
            'bad', 'terrible', 'awful', 'horrible', 'disgusting', 'hate',
            'dislike', 'angry', 'sad', 'disappointed', 'frustrated', 'annoyed',
            'upset', 'worried', 'concerned', 'poor', 'worst'
        }
        
        # 文本预处理
        text_lower = text.lower()
        words = re.findall(r'\b\w+\b', text_lower)
        
        # 计算情感分数
        positive_count = sum(1 for word in words if word in positive_words)
        negative_count = sum(1 for word in words if word in negative_words)
        total_words = len(words)
        
        if total_words == 0:
            sentiment_score = 0.0
            sentiment_label = "neutral"
        else:
            sentiment_score = (positive_count - negative_count) / total_words
            
            if sentiment_score > 0.1:
                sentiment_label = "positive"
            elif sentiment_score < -0.1:
                sentiment_label = "negative"
            else:
                sentiment_label = "neutral"
        
        return {
            "sentiment_score": float(sentiment_score),
            "sentiment_label": sentiment_label,
            "positive_words_count": positive_count,
            "negative_words_count": negative_count,
            "total_words": total_words,
            "confidence": abs(sentiment_score),
            "method": "lexicon_based"
        }
    
    def text_similarity(self, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """文本相似度计算"""
        text1 = params.get("text1", "")
        text2 = params.get("text2", "")
        method = params.get("method", "cosine")
        
        if not text1 or not text2:
            raise ValueError("Text similarity requires 'text1' and 'text2' parameters")
        
        # 文本预处理
        def preprocess_text(text):
            text_lower = text.lower()
            words = re.findall(r'\b\w+\b', text_lower)
            return words
        
        words1 = preprocess_text(text1)
        words2 = preprocess_text(text2)
        
        if method == "jaccard":
            # Jaccard相似度
            set1 = set(words1)
            set2 = set(words2)
            intersection = len(set1.intersection(set2))
            union = len(set1.union(set2))
            similarity = intersection / union if union > 0 else 0.0
            
        elif method == "cosine":
            # 余弦相似度
            all_words = list(set(words1 + words2))
            
            # 创建词频向量
            vec1 = [words1.count(word) for word in all_words]
            vec2 = [words2.count(word) for word in all_words]
            
            # 计算余弦相似度
            dot_product = sum(a * b for a, b in zip(vec1, vec2))
            magnitude1 = math.sqrt(sum(a * a for a in vec1))
            magnitude2 = math.sqrt(sum(a * a for a in vec2))
            
            if magnitude1 == 0 or magnitude2 == 0:
                similarity = 0.0
            else:
                similarity = dot_product / (magnitude1 * magnitude2)
                
        elif method == "levenshtein":
            # 编辑距离相似度
            def levenshtein_distance(s1, s2):
                if len(s1) < len(s2):
                    return levenshtein_distance(s2, s1)
                
                if len(s2) == 0:
                    return len(s1)
                
                previous_row = list(range(len(s2) + 1))
                for i, c1 in enumerate(s1):
                    current_row = [i + 1]
                    for j, c2 in enumerate(s2):
                        insertions = previous_row[j + 1] + 1
                        deletions = current_row[j] + 1
                        substitutions = previous_row[j] + (c1 != c2)
                        current_row.append(min(insertions, deletions, substitutions))
                    previous_row = current_row
                
                return previous_row[-1]
            
            distance = levenshtein_distance(text1, text2)
            max_len = max(len(text1), len(text2))
            similarity = 1 - (distance / max_len) if max_len > 0 else 1.0
            
        else:
            raise ValueError(f"Unknown similarity method: {method}")
        
        return {
            "similarity": float(similarity),
            "method": method,
            "text1_words": len(words1),
            "text2_words": len(words2),
            "common_words": len(set(words1).intersection(set(words2))),
            "total_unique_words": len(set(words1).union(set(words2)))
        }
    
    def keyword_extraction(self, data: List[float], params: Dict[str, str]) -> Dict[str, Any]:
        """关键词提取"""
        text = params.get("text", "")
        n_keywords = int(params.get("n_keywords", "5"))
        method = params.get("method", "tfidf")
        
        if not text:
            raise ValueError("Keyword extraction requires 'text' parameter")
        
        # 文本预处理
        text_lower = text.lower()
        sentences = re.split(r'[.!?]+', text_lower)
        
        # 移除停用词（简化版本）
        stop_words = {
            'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
            'of', 'with', 'by', 'from', 'up', 'about', 'into', 'through', 'during',
            'before', 'after', 'above', 'below', 'out', 'off', 'over', 'under',
            'again', 'further', 'then', 'once', 'here', 'there', 'when', 'where',
            'why', 'how', 'all', 'any', 'both', 'each', 'few', 'more', 'most',
            'other', 'some', 'such', 'no', 'nor', 'not', 'only', 'own', 'same',
            'so', 'than', 'too', 'very', 'can', 'will', 'just', 'should', 'now',
            'is', 'are', 'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had'
        }
        
        # 提取所有单词
        all_words = []
        for sentence in sentences:
            words = re.findall(r'\b\w+\b', sentence)
            words = [word for word in words if word not in stop_words and len(word) > 2]
            all_words.extend(words)
        
        if not all_words:
            return {
                "keywords": [],
                "scores": [],
                "method": method,
                "total_words": 0
            }
        
        if method == "frequency":
            # 简单词频
            word_counts = Counter(all_words)
            top_words = word_counts.most_common(n_keywords)
            keywords = [word for word, count in top_words]
            scores = [count for word, count in top_words]
            
        elif method == "tfidf":
            # 简化的TF-IDF
            word_freq = Counter(all_words)
            total_words = len(all_words)
            
            # 计算TF-IDF分数
            tfidf_scores = {}
            for word, freq in word_freq.items():
                tf = freq / total_words
                # 简化的IDF计算（假设文档中每个词都只出现在一个"文档"中）
                idf = math.log(len(sentences) / (1 + sum(1 for s in sentences if word in s)))
                tfidf_scores[word] = tf * idf
            
            # 获取top N关键词
            sorted_words = sorted(tfidf_scores.items(), key=lambda x: x[1], reverse=True)
            top_words = sorted_words[:n_keywords]
            keywords = [word for word, score in top_words]
            scores = [score for word, score in top_words]
            
        else:
            raise ValueError(f"Unknown keyword extraction method: {method}")
        
        return {
            "keywords": keywords,
            "scores": [float(score) for score in scores],
            "method": method,
            "total_words": len(all_words),
            "unique_words": len(set(all_words)),
            "n_keywords": len(keywords)
        } 