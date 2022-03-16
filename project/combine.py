import sys, os, fire
from PIL import Image
import numpy as np

class PLT(object):
    def combine(self, which, n, alpha):
        f1 = os.path.join("data", "IndependentSet_Regular%dd3seed%d"%(n,1) if which == "regular" else "IndependentSet_Diag%dx%df0.8seed%d"%(n,n,1))
        maxn = np.loadtxt(os.path.join(f1, "SizeMax1.dat")).item()
        K = np.ceil(maxn * alpha)
        image1 = Image.open(os.path.join(f1, 'hamming-K%d-n10000.png'%K))
        total_width = image1.size[0] * 10
        total_height = image1.size[1] * 10
        new_im = Image.new('RGB', (total_width, total_height))

        for i in range(10):
            for j in range(10):
                seed = i*10+j+1
                fi = os.path.join("data", "IndependentSet_Regular%dd3seed%d"%(n,seed) if which == "regular" else "IndependentSet_Diag%dx%df0.8seed%d"%(n,n,seed))
                maxn = np.loadtxt(os.path.join(fi, "SizeMax1.dat")).item()
                K = np.ceil(maxn * alpha)
                filename = os.path.join(fi, 'hamming-K%d-n10000.png'%K)
                image = Image.open(filename)
                x_offset = i * image1.size[0]
                y_offset = j * image1.size[1]
                new_im.paste(image, (x_offset, y_offset))

        new_im.save('combined-%s%d-alpha%s.jpg'%(which, n, alpha))

fire.Fire(PLT)
