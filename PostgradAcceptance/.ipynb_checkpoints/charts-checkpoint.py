def style_telegram_vertical_barchart(ax, plot_title, xlabel='Ось x', ylabel='Ось y'):
    """
    Стилизует существующий вертикальный барчарт в стиле 'lone analyst' и сохраняет .svg файл в текущую директорию
    
    Требуются matplotlib.pyplot и matplotlib.font_manager

    Parameters:
    ax (matplotlib.axes.Axes): Объект axes с графиком
    plot_title (str): Название графика
    xlabel(str): Название оси x (подтянется из графика, но можно задать самому)
    ylabel(str): Название оси y (подтянется из графика, но можно задать самому)
    """
    
    import matplotlib.pyplot as plt
    import matplotlib.font_manager as fm
    
    # Устанавливаем размер figure для точного размера 960x840 пикселей
    fig = ax.get_figure()
    fig.set_size_inches(9.6, 8.4)
    fig.set_dpi(100)
    
    # Меняем цвет столбцов на #5E8AFF
    for patch in ax.patches:
        if isinstance(patch, plt.Rectangle):  # Проверяем, что это столбец
            patch.set_color('#5E8AFF')
            patch.set_edgecolor('none')
    
    # Меняем цвет текста значений над столбцами
    for text in ax.texts:
        text.set_color('#2C2C2C')
        text.set_fontsize(12)
    
    # Пытаемся установить шрифт Inter
    try:
        inter_font = fm.findfont(fm.FontProperties(family=['Inter']))
        font_prop = fm.FontProperties(fname=inter_font)

        ax.title.set_fontproperties(font_prop)
        ax.xaxis.label.set_fontproperties(font_prop)
        ax.yaxis.label.set_fontproperties(font_prop)
        
        for label in ax.get_xticklabels() + ax.get_yticklabels():
            label.set_fontproperties(font_prop)
            
        for text in ax.texts:
            text.set_fontproperties(font_prop)
            
    except:
        # Если Inter не найден, используем стандартный sans-serif
        plt.rcParams['font.family'] = 'sans-serif'
        print("Шрифт Inter не найден. Используется стандартный sans-serif шрифт.")
    
    ax.set_title(None)
    
    # Настраиваем цвет меток осей
    ax.tick_params(axis='x', colors='#2C2C2C')
    ax.tick_params(axis='y', colors='#2C2C2C')
    
    # Убираем рамку (spines) кроме нижней
    for spine in ['top', 'right', 'left']:
        ax.spines[spine].set_visible(False)
    
    # Оставляем нижнюю ось, но делаем ее серой
    ax.spines['bottom'].set_visible(True)
    ax.spines['bottom'].set_color('#5C5C5C')
    ax.spines['bottom'].set_linewidth(0.5)
    
    # Убираем деления
    ax.tick_params(axis='y', left=False)
    ax.tick_params(axis='x', which='both', bottom=False, top=False)
    
    # Убираем сетку
    ax.grid(False)
    
    # Убираем ось Y
    ax.set_yticks([])
    
    # Настраиваем отступы
    fig.tight_layout()
    
    # Показываем график
    plt.show()
    
    # Сохраняем с прозрачным фоном в SVG
    filename = f"{plot_title.lower().replace(' ', '_')}.svg"
    fig.savefig(filename, format='svg', transparent=True, bbox_inches='tight')
    print(f"График сохранен как: {filename}")
    
    return ax

def style_telegram_horizontal_barchart(ax, plot_title, xlabel='Ось x', ylabel='Ось y'):
    """
    Стилизует существующий график в горизонтальный барчарт в стиле 'lone analyst' и сохраняет .svg файл в текущую директорию
    
    Требуются matplotlib.pyplot и matplotlib.font_manager
    
    Parameters:
    ax (matplotlib.axes.Axes): Объект axes с графиком
    plot_title (str): Название графика
    xlabel(str): Название оси x (подтянется из графика, но можно задать самому)
    ylabel(str): Название оси y (подтянется из графика, но можно задать самому)
    """
    import matplotlib.pyplot as plt
    import matplotlib.font_manager as fm
    
    # Устанавливаем размер figure для точного размера 960x840 пикселей
    fig = ax.get_figure()
    fig.set_size_inches(9.6, 8.4)  # 9.6*100 = 960, 8.4*100 = 840
    fig.set_dpi(100)
    
    # Меняем цвет столбцов на #5E8AFF
    for patch in ax.patches:
        if isinstance(patch, plt.Rectangle):  # Проверяем, что это столбец
            patch.set_color('#5E8AFF')
            patch.set_edgecolor('none')
    
    # Меняем цвет текста значений над столбцами
    for text in ax.texts:
        text.set_color('#2C2C2C')
        text.set_fontsize(12)
    
    # Пытаемся установить шрифт Inter
    try:
        # Пытаемся найти Inter в системе
        inter_font = fm.findfont(fm.FontProperties(family=['Inter']))
        font_prop = fm.FontProperties(fname=inter_font)
        
        # Применяем шрифт ко всем текстовым элементам
        ax.title.set_fontproperties(font_prop)
        ax.xaxis.label.set_fontproperties(font_prop)
        ax.yaxis.label.set_fontproperties(font_prop)
        
        for label in ax.get_xticklabels() + ax.get_yticklabels():
            label.set_fontproperties(font_prop)
            
        for text in ax.texts:
            text.set_fontproperties(font_prop)
            
    except:
        # Если Inter не найден, используем стандартный sans-serif
        plt.rcParams['font.family'] = 'sans-serif'
        print("Шрифт Inter не найден. Используется стандартный sans-serif шрифт.")
    
    # Обновляем заголовок
    ax.set_title(None)
    
    # Настраиваем цвет меток осей
    ax.tick_params(axis='x', colors='#2C2C2C')
    ax.tick_params(axis='y', colors='#2C2C2C')
    
    # Убираем рамку (spines)
    for spine in ['top', 'right', 'left', 'bottom']:
        ax.spines[spine].set_visible(False)
    
    # Убираем деления
    ax.tick_params(axis='y', left=False)
    ax.tick_params(axis='x', which='both', bottom=False, top=False)
    
    # Убираем сетку
    ax.grid(False)
    
    # Убираем ось Y
    ax.set_xticks([])
    
    # Настраиваем отступы
    fig.tight_layout()
    
    # Показываем график
    plt.show()
    
    # Сохраняем с прозрачным фоном в SVG
    filename = f"{plot_title.lower().replace(' ', '_')}.svg"
    fig.savefig(filename, format='svg', transparent=True, bbox_inches='tight')
    print(f"График сохранен как: {filename}")
    
    return ax