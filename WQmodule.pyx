import os
cimport cython
from cpython.array cimport array
import matplotlib as pl
from math import sqrt
import datetime
import time
import math
import random
import matplotlib.pyplot as plt
from matplotlib.backends.backend_pdf import PdfPages
from multiprocessing.pool import ThreadPool
import numpy as np
from multiprocessing.pool import ThreadPool
from libc.math cimport log as ln, pow, fabs, exp

cdef inline int sign(double x):
	if x > 0:
		return 1
	elif x < 0:
		return -1
	else:
		return 0


class DATA:
	def __init__(self, timeperiod, directory):
		self.period = timeperiod
		self.dir = directory

	def get_data(self, type_of_data):
		files = [file_name for file_name in os.listdir(self.dir) if '.csv' in file_name]
		files.sort();

		cdef int N_STOCKS = len(files)
		cdef:
			int day
			int stock
			int i
			int j = 0

		if type_of_data == 'date':
			k = 5

		if type_of_data == 'close':
			k = 6
	
		if type_of_data == 'open':
			k = 7

		if type_of_data == 'high':
			k = 3

		if type_of_data == 'low':
			k = 4
	
		if type_of_data == 'volume':
			k = 0

		if type_of_data == 'adj_close':
			k = 2

		final_data = []
		
		for i in xrange(N_STOCKS):
			f = open(self.dir + files[i], 'r')
			data = f.readlines()
			f.close()

			for day in xrange(len(data)-1):
				day_data = data[day+1].split(',')
				if float(day_data[0]) == 0:
					print files[i]
				if day_data[5] >= self.period[0]:
					j = 0
					while day_data[5] <= self.period[1]:
						if i == 0:
							final_data.append([])
						if float(day_data[0]) == 0:
							print files[i]
						final_data[j].append(float(day_data[k]))
						j = j + 1
						day_data = data[day + 1 + j].split(',')
					break
		return final_data



def neutralization(array):
	cdef int i
	cdef double mean = E(array)

	for i in xrange(len(array)):
		if array[i] != 0:
			array[i] = array[i] - mean
	return array

def scaling(array):
	cdef int i
	cdef double sum_abs = 0
	for i in xrange(len(array)):
		sum_abs = sum_abs + abs(array[i])
	if sum_abs != 0:
		for i in xrange(len(array)):
			array[i] = array[i] / sum_abs
		return array
	else:
		return array

cdef double E(array):
	cdef int i
	cdef double j = 1
	cdef double mean = 0
	for i in xrange(len(array)):
		mean = mean + array[i]
		if array[i] != 0:
			j = j + 1
	
	mean = mean / j
	return mean

cdef double var(array):
	cdef int i
	cdef double var = 0
	cdef double j = 1
	cdef double mean = E(array)
	for i in xrange(len(array)):
		if array[i] != 0:
			var = var + (array[i] - mean) * (array[i] - mean)
			j = j + 1
	
	var = var / j
	return sqrt(var)

cdef double summ(array):
	cdef int i
	cdef double summ = 0
	for i in xrange(len(array)):
		summ = summ + array[i]
	return summ

def RB(close, openp, int begin):
	cdef int i
	cdef array rb = array('d',[])
	for i in xrange(begin, len(close)):
		rb.append(abs(close[i] - openp[i]) / openp[i])
	return rb

def US(close, openp, high, int begin):
	cdef int i
	cdef array us = array('d',[])
	for i in xrange(begin, len(close)):
		if (high[i] - openp[i]) != 0:
			us.append((close[i] - openp[i]) / (high[i] - openp[i]))
		else:
			us.append(0)
	return us

def LS(close, openp, low, int begin):
	cdef int i
	cdef array ls = array('d',[])
	for i in xrange(begin, len(close)):
		if (close[i] - low[i]) != 0:
			ls.append((close[i] - openp[i])/(close[i] - low[i]))
		else:
			ls.append(0)
	return ls

def HL(high, low, int begin):
	cdef int i
	cdef array hl = array('d',[])
	for i in xrange(begin, len(high)):
		hl.append((high[i] - low[i]) / low[i])
	return hl		

def EMA(signal, double n):
	cdef int i
	cdef double a = 2 / (n + 1)
	cdef array ema = array('d',[])
	ema.append(signal[0])
	for i in xrange(1, len(signal)):
		ema.append(ema[i - 1] + a * (signal[i] - ema[i - 1]))
	return ema

def DB4 (signal, int begin, filters = 'HnL'):
	cdef int i
	cdef array high = array('d', [-0.1830127/2, -0.3169873/2, 
		1.1830127/2, -0.6830127/2])
	cdef array low = array('d', [0.6830127/2, 1.1830127/2,
		0.3169873/2, -0.1830127/2])
	cdef array hpass = array('d', [])
	cdef array lpass = array('d', [])
	if filters == 'HnL':
		hnl = []
		for i in xrange(begin, len(signal)):
			hpass.append(high[0] * signal[i] + high[1] * signal[i - 1] + high[2] * signal[i - 2] + high[3] * signal[i - 3])
			lpass.append(low[0] * signal[i] + low[1] * signal[i - 1] + low[2] * signal[i - 2] + low[3] * signal[i - 3])
		hnl.append(lpass)
		hnl.append(hpass)
		return hnl
	if filters == 'low':
		for i in xrange(begin, len(signal)):
			lpass.append(low[0] * signal[i] + low[1] * signal[i - 1] + low[2] * signal[i - 2] + low[3] * signal[i - 3])		
		return lpass
	if filters == 'high':
		for i in xrange(begin, len(signal)):
			hpass.append(high[0] * signal[i] + high[1] * signal[i - 1] + high[2] * signal[i - 2] + high[3] * signal[i - 3])
		return hpass


def DB6(signal, int begin, filters = 'HnL'):
	cdef int i
	cdef int j
	cdef double sum_1
	cdef double sum_2
	cdef array low = array('d', [0.47046721/2, 1.14111692/2,
		0.650365/2, -0.19093442/2, -0.12083221/2, 0.0498175/2])
	cdef array high = array('d', [low[5], -low[4], 
		low[3], -low[2], low[1], -low[0]])
	cdef array hpass = array('d', [])
	cdef array lpass = array('d', [])

	if filters == 'HnL':
		hnl = []
		for i in xrange(begin, len(signal)):
			sum_1 = 0
			sum_2 = 0
			for j in xrange(len(high)):
				sum_1 = sum_1 + high[j] * signal[i - j]
				sum_2 = sum_2 + low[j] * signal[i - j]
			hpass.append(sum_1)
			lpass.append(sum_2)
		hnl.append(lpass)
		hnl.append(hpass)
		return hnl

	if filters == 'low':
		for i in xrange(begin, len(signal)):
			sum_2 = 0
			for j in xrange(len(high)):
				sum_2 = sum_2 + low[j] * signal[i - j]
			lpass.append(sum_2)				
		return lpass

	if filters == 'high':
		for i in xrange(begin, len(signal)):
			sum_1 = 0
			for j in xrange(len(high)):
				sum_1 = sum_1 + high[j] * signal[i - j]
			hpass.append(sum_2)	
		return hpass


def DB12(signal, int begin, filters = 'HnL'):
	cdef int i
	cdef int j
	cdef double sum_1
	cdef double sum_2
	cdef array low = array('d', [0.15774243/2, 0.69950381/2,
		1.06226376/2, 0.44583132/2, -0.31998660/2, -0.18351806/2, 0.13788809/2,
		0.03892321/2, -0.04466375/2, 7.83251152e-4/2, 6.75606236e-3/2, -1.52353381e-3/2])
	cdef array high = array('d', [low[11], -low[10], 
		low[9], -low[8], low[7], -low[6], low[5], -low[4], low[3], -low[2], low[1], -low[0]])
	cdef array hpass = array('d', [])
	cdef array lpass = array('d', [])

	if filters == 'HnL':
		hnl = []
		for i in xrange(begin, len(signal)):
			sum_1 = 0
			sum_2 = 0
			for j in xrange(len(high)):
				sum_1 = sum_1 + high[j] * signal[i - j]
				sum_2 = sum_2 + low[j] * signal[i - j]
			hpass.append(sum_1)
			lpass.append(sum_2)
		hnl.append(lpass)
		hnl.append(hpass)
		return hnl

	if filters == 'low':
		for i in xrange(begin, len(signal)):
			sum_2 = 0
			for j in xrange(len(high)):
				sum_2 = sum_2 + low[j] * signal[i - j]
			lpass.append(sum_2)				
		return lpass

	if filters == 'high':
		for i in xrange(begin, len(signal)):
			sum_1 = 0
			for j in xrange(len(high)):
				sum_1 = sum_1 + high[j] * signal[i - j]
			hpass.append(sum_2)	
		return hpass

def vwap(prices, volume, int n, int begin):
	cdef int i
	cdef int j
	cdef double vwap_0 = 0
	cdef double vol = 0
	cdef array transform = array('d', [])
	for j in xrange(begin - n ,begin):
		vwap_0 = vwap_0 + prices[j] * volume[j]
		vol = vol + volume[j]
	for i in xrange(begin, len(prices)):
		vwap_0 = vwap_0 - prices[i - n] * volume[i - n] + prices[i] * volume[i]
		vol = vol - volume[i - n] + volume[i]
		if volume[i] == 0:
			print 'da'
		if vol == 0:
			transform.append(transform[i - begin - 1])
		else:
			transform.append(vwap_0/vol)
	return transform

def returns(prices, int n, int begin):
	cdef int i
	cdef array returns = array('d', [])
	for i in xrange(begin, len(prices)):
		returns.append(prices[i] / prices[i - n] - 1)
	return returns

def sma(signal, int n, int begin):
	cdef int i
	cdef double ma_0 = 0
	cdef array ma = array('d', [])
	for i in xrange(n):
		ma_0 = ma_0 + signal[begin - i]
	ma_0 = ma_0 / float(n)
	ma.append(ma_0)
	for i in xrange(begin + 1, len(signal)):
		ma_0 = ma_0 - signal[i - 1 - n] / float(n) + signal[i] / float(n)
		ma.append(ma_0)
	return ma


def stddev(signal, int n, int begin):
	cdef int i
	cdef double std_0 = 0
	cdef double a
	cdef double b
	cdef array std = array('d', [])
	cdef array ma = sma(signal, n ,begin)
	for i in xrange(n):
		std_0 = std_0 + (signal[begin - i] - ma[0]) * (signal[begin - i] - ma[0])
	std_0 = std_0 / float(n)
	if std_0 > 1e-5:
		std.append(sqrt(std_0))
	else:
		std.append(0)
	for i in xrange(begin + 1, len(signal)):
		a = (signal[i - 1 - n] - ma[i - begin - 1])*(signal[i - 1 - n] - ma[i - begin - 1]) / float(n)
		b = (signal[i] - ma[i - begin]) * (signal[i] - ma[i - begin]) / float(n)
		std_0 = std_0 - a + b
		if std_0 > 1e-5:
			std.append(sqrt(std_0))
		else:
			std.append(0)
	return std


def meanreversion(signal, int n, int begin):
	cdef int i
	cdef array ma = sma(signal, n ,begin)
	cdef array std = stddev(signal, n, begin)
	cdef array mr = array('d', [])
	for i in xrange(begin, len(signal)):
		if std[i-begin] > 0:
			mr.append((signal[i] - ma[i-begin])/std[i-begin])
		else: 
			mr.append(0)
	return mr


def PlotSignal(signal, directory_nameofimage):
		plt.figure(figsize=(16,12))
		plot = plt.plot(signal)
		plt.savefig(directory_nameofimage)







class alpha:
	
	def __init__(self, alphasignal, closeprices, int delay = 0, str neutralization = 'no'):
		self.delay = delay
		self.alphasignal = alphasignal
		self.neutralization = neutralization
		self.close = closeprices


	def simulation(self):
		cdef array PnL = array('d',[])
		cdef array returns = array('d',[])
		cdef int j
		cdef int i
		cdef double CASH = 20000000
		for i in xrange(1, len(self.close) - self.delay):
			weights = self.alphasignal(i-1)
			if self.neutralization == 'yes':
				weights = neutralization(scaling(weights))
				returns = array('d', [])
				for j in xrange(len(self.close[i])):
					if self.close[i+self.delay][j] != 0 and self.close[i-1+self.delay][j] != 0:
						returns.append(weights[j]*CASH*(self.close[i+self.delay][j]/self.close[i-1+self.delay][j] - 1))
			else:
				weights = scaling(weights)
				returns = array('d', [])
				for j in xrange(len(self.close[i])):
					if self.close[i+self.delay][j] != 0 and self.close[i-1+self.delay][j] != 0:
						returns.append(weights[j]*CASH*(self.close[i+self.delay][j]/self.close[i-1+self.delay][j] - 1))
			PnL.append(summ(returns))
		return PnL

	def alphaperfomance(self, str directory_nameofimage):
		cdef double Mean = 0
		cdef double Var = 0
		cdef double Sharp
		cdef int i
		cdef array equity = array('d',[])
		equity.append(0)
		PnL = self.simulation()
		for i in xrange(len(PnL)):
			equity.append(equity[i] + PnL[i])
		
		Mean = E(PnL)
		Var = var(PnL)
		Sharp = sqrt(len(PnL))*Mean/Var
		plt.figure(figsize=(16,12))
		plot = plt.plot(equity)
		plt.text(10,max(equity),'Sharp='+str(Sharp))
		plt.savefig(directory_nameofimage)
		print('Sharp='+str(Sharp))


class alpha_generator:

	def __init__(self, features_directory, numbers_of_features):
		self.directory = features_directory
		self.returns = []
		self.featureslist = numbers_of_features
		self.insample = self.__get_features()
		self.outsample = []
		self.returns_out = []
		self.number_of_stocks = len(self.insample[0][0, :])
		self.a = -20
		self.b = 20
		self.logfiles = ''

	def __get_features(self):
		cdef int i
		cdef int j
		cdef int k
		cdef array rows
		cdef array returns_1
		list_of_features = []
		returns = []
		files = [file_name for file_name in os.listdir(self.directory) if '.csv' in file_name]
		for i in xrange(len(self.featureslist)):
			feature = []
			for j in xrange(len(files)/3):
				file_1 = open(self.directory + 'insample' + str(j) + '.csv', 'r')
				data = file_1.readlines()
				row = data[self.featureslist[i]].split(';')
				rows = array('d', [])
				for k in xrange(len(row) - 1):
					rows.append(float(row[k]))
				feature.append(rows)
				file_1.close()
				if i == 0:
					file_2 = open(self.directory + 'returns' + str(j) + '.csv', 'r')
					returns_0 = file_2.readlines()
					string = returns_0[0].split(';')
					returns_1 = array('d', [])
					for k in xrange(len(string) - 1):
						returns_1.append(float(string[k]))
					returns.append(returns_1)
					file_2.close()
			feature = np.array(feature)
			feature = np.transpose(feature)
			list_of_features.append(feature)
		returns = np.array(returns)
		returns = np.transpose(returns)
		self.returns = returns
		return list_of_features

	def out_linear_model(self, combination):
		cdef array PnL = array('d',[])
		cdef array returns = array('d',[])
		cdef array weights = array('d',[])
		cdef array equity = array('d',[])
		cdef double Sharp
		cdef int j
		cdef int i
		cdef double CASH = 20000000
		output = []
		for i in xrange(len(self.returns)):
			returns = array('d', [])
			weights = scaling(self.__alpha(combination, i))
			for j in xrange(len(self.returns[i])):
				returns.append(weights[j]*CASH*self.returns[i, j])
			PnL.append(sum(returns))
		Sharp = sqrt(float(252))*E(PnL)/var(PnL)
		equity.append(0)
		for i in xrange(len(PnL)):
			equity.append(equity[i] + PnL[i])
		output.append(abs(Sharp))
		output.append(equity)
		return output

	def plot_linear_model(self, combination, str directory_of_plot):
		cdef array PnL = array('d',[])
		cdef array returns = array('d',[])
		cdef array weights = array('d',[])
		cdef array equity = array('d',[])
		cdef double Sharp
		cdef int j
		cdef int i
		cdef double CASH = 20000000
		for i in xrange(len(self.returns)):
			returns = array('d', [])
			weights = scaling(self.__alpha(combination, i))
			for j in xrange(len(self.returns[i])):
				returns.append(weights[j]*CASH*self.returns[i, j])
			PnL.append(sum(returns))

		equity.append(0)
		for i in xrange(len(PnL)):
			equity.append(equity[i] + PnL[i])

		plt.figure(figsize=(16,12))
		plot = plt.plot(equity)
		plt.text(1,max(equity)-4,'Sharp='+str(Sharp))
		plt.savefig(directory_of_plot)

	def __alpha(self, combination, int day):
		cdef int i
		cdef int j
		cdef double curr_result
		cdef array alpha = array('d',[])

		for i in xrange(self.number_of_stocks):
			curr_result = 0
			for j in xrange(len(combination)):
				curr_result = curr_result + combination[j]*self.insample[j][day, i]
			alpha.append(curr_result)
		return alpha

	def train_linear_model(self, double T_0, logfiles, double a = -50, double b = 50, console = True):
		cdef int i = 0
		cdef int j
		cdef int k = 0
		cdef str string
		cdef double D = float(len(self.insample))
		cdef int size = len(self.insample)
		cdef double r = random.random()
		cdef double T = T_0
		cdef double E_1
		cdef double E_2
		cdef array x = random_vector(size)
		cdef array PnL = array('d', [])
		cdef array x_1
		cdef array x_2
		solutions = []
		cdef str name  = logfiles + 'linear_model_train_logs' + datetime.datetime.now().strftime("%I:%M%p on %B %d, %Y") + str(random.randint(0, 500))+ '.csv'

		E_1 = self.out_linear_model(x)[0]

		string = 'feature' + str(self.featureslist[0])
		for j in xrange(1, len(self.featureslist)):
			if j != len(self.featureslist) - 1:
				string = string + ';' + 'feature' + str(self.featureslist[j])
			else:
				string = string + ';' + 'feature' + str(self.featureslist[j]) + ';' + 'Sharp' + '\n'

		logs = open(name, 'wb')
		logs.write(string)
		logs.close()
		while T > 0.04:

			x_1 = new_solution(x, T, a, b)
			E_2 = self.out_linear_model(x_1)[0]

			while (r > Gibbs(E_1, E_2, T)) or (fabs(E_1 - E_2) < 1e-10):
				x_1 = new_solution(x, T, a, b)
				E_2 = self.out_linear_model(x_1)[0]
				r = random.random()
			copy_array_2(x_1, x)
			E_1 = E_2
			if (E_1 > 0.9):
				logs = open(name, 'a')
				x_2 = array('d', [])
				copy_array(x, x_2)
				x_2.append(E_1)
				logs.write(getline_from_array(x_2))
				logs.close()
				k = k + 1
			if console == True:
				print 'Sharp = ' + str(E_1)
			i = i + 1
			T = T_0 * exp(-pow(float(i), 1/D)) * exp(-10 / D)






def new_solution(x, double T, double a, double b):
	cdef int i
	cdef double r
	cdef array x_1 = array('d', [])
	for i in xrange(len(x)):
		x_1.append(0)
		r = random.random()
		z = fast_density(r, T)
		x_1[i] = x[i] + z * (b - a)
		while (x_1[i] - a) * (b - x_1[i]) < 0:
			r = random.random()
			z = fast_density(r, T)
			x_1[i] = x[i] + z * (b - a)
	return x_1


def Gibbs(double E_1, double E_2, double T):
	return exp((E_2 - E_1) / T)


def fast_density(double a, double T):
	cdef double z = sign(a - 0.5) * T * (pow((1 + 1 / T), fabs(2 * a - 1)) - 1)
	return z

def random_vector(int size):
	cdef int i
	cdef array vector = array('d', [])

	for i in xrange(size):
		vector.append(10 * (random.random() - 1))

	return vector


def random_vector_int(int size):
	cdef int i
	cdef array vector = array('i', [])

	for i in xrange(size):
		vector.append(random.randint(0, 15))

	return vector


def getline_from_array(array):
	cdef int i
	cdef str string = str(array[0])

	for i in xrange(1, len(array)):
		if i!= len(array) - 1:
			string = string + ';' + str(array[i])
		else:
			string = string + ';' + str(array[i]) + '\n'

	return string

def copy_array(from_l , to_l):
	cdef int i
	for i in xrange(len(from_l)):
		to_l.append(from_l[i])

def copy_array_2(from_l , to_l):
	cdef int i
	for i in xrange(len(from_l)):
		to_l[i] = from_l[i]

def parallel_training_linear(int size, str directory, str logfiles, double a = -50, double b = 50):
	cdef int i
	generators = []

	for i in xrange(size):
		generator = alpha_generator(directory, random_vector_int(random.randint(6,10)))
		generator.a = a
		generator.b = b
		generator.logfiles = logfiles
		generators.append(generator)
		print 'Creating the generators.......' + str(100*float(i+1)/float(size)) + '%'

	print 'Start train models'
	pool = ThreadPool(12)
	pool.map(parallel_train, generators)
	pool.close()
	pool.join()


def parallel_train(generator):

	generator.train_linear_model(2, generator.logfiles, a = generator.a, b = generator.b)

















