# Соберите информацию о заквасках с сайта pro-syr.ru 
# (https://pro-syr.ru/zakvaski-dlya-syra/mezofilnye/)
# Необходимо собрать следующие данные:
# Название продукта
# Цена
# Есть ли продукт в наличии
# Результат должен быть записан в CSV файл

import scrapy
from scrapy import Request

class ProsyrSpider(scrapy.Spider):

    name = 'ProsyrSpider'
    start_urls = ['https://pro-syr.ru/zakvaski-dlya-syra/mezofilnye/']
    
    def start_requests(self):
        for url in self.start_urls:
            yield Request(url=url, callback=self.parse)

    def parse(self, response):
        products = response.css('div.product-thumb  ')
        data = []
 
        for product in products:

            product_name = product.css('div.nameproduct a::text').get()
            price = product.css('p.price::text').get().replace('\n', '').strip()
            button = product.css("div.button-group button span::text").get()

            if button=='В корзину':
                is_available = 1
            else:
                is_available = 0
                
            yield {
                'product_name': product_name,
                'price': price,
                'is_available': is_available
            }
            
        next_page_buttons = response.css('ul.pagination li a')
        for button in next_page_buttons:
            next_page_text = button.css('a::text').get()
            if next_page_text == '>':
                next_page_link = button.css('a::attr(href)').get()
                yield response.follow(next_page_link, self.parse)
                break

# cd .\scrapy_parsing\ 
# scrapy crawl 'ProsyrSpider' -o 'prosyr.csv'