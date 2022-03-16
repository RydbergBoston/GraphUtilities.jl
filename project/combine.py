import sys, os, fire
from PIL import Image

def findfile(folder):
    for K in range(1,21):
        name = os.path.join(folder, 'hamming-K%d-n10000.png'%K)
        print(name)
        if os.path.isfile(name):
            return name

class PLT(object):
    def combine(self, which, n):
        image1 = Image.open(findfile("data/IndependentSet_Regular%dd3seed%d"%(n,1) if which == "regular" else "IndependentSet_Diag%dx%df0.8seed%d"%(n,n,1)))
        total_width = image1.size[0] * 10
        total_height = image1.size[1] * 10
        new_im = Image.new('RGB', (total_width, total_height))

        for i in range(10):
            for j in range(10):
                seed = i*10+j+1
                image = Image.open(findfile("data/IndependentSet_Regular%dd3seed%d"%(n,seed) if which == "regular" else "IndependentSet_Diag%dx%df0.8seed%d"%(n,n,seed)))
                x_offset = i * image1.size[0]
                y_offset = j * image1.size[1]
                new_im.paste(image, (x_offset, y_offset))

        new_im.save('combined-%s%d.jpg'%(which, n))

fire.Fire(PLT)
